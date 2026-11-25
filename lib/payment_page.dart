import 'package:cloud_functions/cloud_functions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moyasar/moyasar.dart';

import 'core/app_config.dart';
import 'core/pricing.dart';
import 'customer_request_tracking_page.dart';
import 'services/firestore_services.dart';

/// صفحة الدفع عبر ميسّر: مدى، فيزا، ماستركارد، STC Pay، و Apple Pay.
///
/// بعد نجاح الدفع يتحقق السيرفر من الدفعة عند ميسّر قبل إرسال الطلب
/// للفنيين، فلا يمكن تجاوز الدفع من التطبيق.
class PaymentPage extends StatefulWidget {
  final String requestId;
  final double totalPrice;
  final String serviceName;

  const PaymentPage({
    super.key,
    required this.requestId,
    required this.totalPrice,
    required this.serviceName,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color cardColor = Color(0xFF20283B);

  bool _verifying = false;

  late final PaymentConfig? _config = AppConfig.moyasarPublishableKey.isEmpty
      ? null
      : PaymentConfig(
          publishableApiKey: AppConfig.moyasarPublishableKey,
          amount: Pricing.toHalalas(widget.totalPrice),
          description: 'Thamer - ${widget.serviceName} - ${widget.requestId}',
          metadata: {'request_id': widget.requestId},
          creditCard: CreditCardConfig(saveCard: false, manual: false),
          applePay: AppConfig.applePayMerchantId.isEmpty
              ? null
              : ApplePayConfig(
                  merchantId: AppConfig.applePayMerchantId,
                  label: 'Thamer',
                  manual: false,
                  saveCard: false,
                ),
        );

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openTracking() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerRequestTrackingPage(requestId: widget.requestId),
      ),
    );
  }

  Future<void> _onPaymentResult(dynamic result) async {
    if (result is PaymentResponse) {
      switch (result.status) {
        case PaymentStatus.paid:
          await _confirm(result.id);
          return;
        case PaymentStatus.failed:
          _show('تم رفض عملية الدفع، جرّب بطاقة أو طريقة ثانية');
          return;
        default:
          _show('لم تكتمل عملية الدفع، حاول مرة ثانية');
          return;
      }
    }

    if (result is PaymentCanceledError) return;

    if (result is NetworkError || result is TimeoutError) {
      // ممكن الدفعة وصلت لميسّر: نتحقق منها تلقائياً عبر Webhook.
      _show('ما وصلنا رد من بوابة الدفع. بنتحقق من الدفعة تلقائياً.');
      _openTracking();
      return;
    }

    if (result is ValidationError) {
      _show('تأكد من بيانات البطاقة');
      return;
    }

    if (result is AuthError) {
      _show('إعدادات بوابة الدفع غير صحيحة، تواصل مع الدعم');
      return;
    }

    _show('تعذر إتمام الدفع، حاول مرة ثانية');
  }

  Future<void> _confirm(String paymentId) async {
    setState(() => _verifying = true);

    try {
      await FirestoreService().confirmPayment(
        requestId: widget.requestId,
        paymentId: paymentId,
      );
      _show('تم الدفع بنجاح، نبحث لك عن أقرب فني');
      _openTracking();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        _show(e.message ?? 'بنتحقق من الدفعة تلقائياً');
        _openTracking();
        return;
      }
      if (mounted) setState(() => _verifying = false);
      _show(e.message ?? 'تعذر التحقق من الدفع');
    } catch (e) {
      // انقطاع الاتصال: الـ Webhook يكمل التحقق.
      _show('بنتحقق من الدفعة تلقائياً خلال لحظات');
      _openTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع'),
        backgroundColor: const Color(0xFF101525),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF101525),
      body: SafeArea(
        child: _verifying
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('جاري التحقق من الدفع...'),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _summary(),
                  const SizedBox(height: 22),
                  if (config == null)
                    const Text(
                      'بوابة الدفع غير مهيأة بعد. أضف مفتاح ميسّر في '
                      'lib/core/app_config.dart',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orangeAccent),
                    )
                  else ...[
                    if (config.applePay != null) ...[
                      ApplePay(
                        config: config,
                        onPaymentResult: _onPaymentResult,
                        buttonType: ApplePayButtonType.order,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _sectionTitle('الدفع بالبطاقة (مدى، فيزا، ماستركارد)'),
                    // نماذج ميسّر مصممة للخلفية الفاتحة.
                    _lightPanel(
                      CreditCard(
                        config: config,
                        onPaymentResult: _onPaymentResult,
                        locale: const Localization.ar(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle('أو عبر STC Pay'),
                    _lightPanel(
                      STCPay(
                        config: config,
                        onPaymentResult: _onPaymentResult,
                        locale: const Localization.ar(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.white54),
                      SizedBox(width: 6),
                      Text(
                        'دفع آمن عبر ميسّر، ولا نحفظ بيانات بطاقتك',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إذا ألغيت الطلب قبل قبول الفني يرجع لك المبلغ كامل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: primaryColor, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'طلب ${widget.serviceName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            Pricing.format(widget.totalPrice),
            style: const TextStyle(
              color: primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _lightPanel(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(data: ThemeData.light(), child: child),
    );
  }
}
