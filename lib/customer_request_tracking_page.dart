import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_page.dart';
import 'core/pricing.dart';
import 'core/request_status.dart';
import 'core/service_catalog.dart';
import 'services/firestore_services.dart';

class CustomerRequestTrackingPage extends StatelessWidget {
  final String requestId;

  const CustomerRequestTrackingPage({super.key, required this.requestId});

  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color backgroundColor = Color(0xFF101525);
  static const Color cardColor = Color(0xFF20283B);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('متابعة الطلب'),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر تحميل بيانات الطلب',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final data = snapshot.data!.data();

          if (data == null || data['customerId'] != user.uid) {
            return const Center(
              child: Text(
                'الطلب غير موجود',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final status = data['status'] ?? '';
          final technicianId = data['technicianId'];
          final showTechnician =
              technicianId is String &&
              (status == 'accepted' ||
                  status == 'waiting_customer_confirmation' ||
                  status == 'completed');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statusCard(status),
                if (showTechnician) ...[
                  const SizedBox(height: 20),
                  _TechnicianCard(
                    requestId: requestId,
                    technicianId: technicianId,
                    data: data,
                    showLiveLocation: status == 'accepted',
                    allowChat:
                        status == 'accepted' ||
                        status == 'waiting_customer_confirmation',
                  ),
                ],
                if (status == 'waiting_customer_confirmation') ...[
                  const SizedBox(height: 20),
                  _actionButton(
                    context,
                    label: 'تأكيد انتهاء الخدمة',
                    icon: Icons.check_circle,
                    color: primaryColor,
                    foreground: Colors.black,
                    successMessage: 'تم تأكيد اكتمال الخدمة، شكراً لك',
                    action: () =>
                        FirestoreService().confirmCompletion(requestId),
                  ),
                ],
                if (status == 'no_technician_available') ...[
                  const SizedBox(height: 20),
                  _actionButton(
                    context,
                    label: 'إعادة البحث عن فني',
                    icon: Icons.refresh,
                    color: primaryColor,
                    foreground: Colors.black,
                    successMessage: 'نبحث لك من جديد',
                    action: () => FirestoreService().retryRequest(requestId),
                  ),
                ],
                const SizedBox(height: 25),
                _detailsCard(data),
                if (RequestStatus.cancellable.contains(status)) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => _confirmCancel(context),
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: const Text(
                      'إلغاء الطلب',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusCard(Object? status) {
    final searching =
        status == 'searching' || status == 'offered' || status == 'rejected';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RequestStatus.color(status).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(
            status == 'completed'
                ? Icons.verified
                : status == 'cancelled'
                ? Icons.cancel_outlined
                : Icons.engineering,
            color: RequestStatus.color(status),
            size: 55,
          ),
          const SizedBox(height: 15),
          Text(
            RequestStatus.customerText(status),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (searching) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: primaryColor),
          ],
          const SizedBox(height: 12),
          SelectableText(
            'رقم الطلب: $requestId',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(Map<String, dynamic> data) {
    final requestType = data['requestType'] == 'technician_with_materials'
        ? 'فني مع توفير المواد'
        : 'فني فقط';
    final description = (data['problemDescription'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل الطلب',
            style: TextStyle(
              color: primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('نوع الخدمة', ServiceCatalog.jobNameOf(data['serviceType'])),
          if (data['deviceType'] != null)
            _infoRow('نوع الجهاز', '${data['deviceType']}'),
          if (data['issueType'] != null)
            _infoRow('المطلوب', '${data['issueType']}'),
          _infoRow('نوع الطلب', requestType),
          if (description.isNotEmpty) _infoRow('الوصف', description),
          _infoRow('مدة العمل', '${data['durationMinutes'] ?? 0} دقيقة'),
          const Divider(color: Colors.white24),
          _infoRow('أجرة العمل', _money(data['laborCost'])),
          _infoRow('رسوم الخدمة', _money(data['appFee'])),
          if ((data['materialsCost'] ?? 0) is num &&
              (data['materialsCost'] ?? 0) > 0)
            _infoRow('المواد', _money(data['materialsCost'])),
          _infoRow('الإجمالي', _money(data['totalPrice'])),
        ],
      ),
    );
  }

  static Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _money(Object? value) =>
      value is num ? Pricing.format(value) : '-';

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color foreground,
    required String successMessage,
    required Future<void> Function() action,
  }) {
    return ElevatedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await action();
          messenger.showSnackBar(SnackBar(content: Text(successMessage)));
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('تعذر تنفيذ العملية: $e')),
          );
        }
      },
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.all(15),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('متأكد تبي تلغي الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'نعم، إلغاء',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreService().cancelRequest(requestId);
      messenger.showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذر إلغاء الطلب: $e')));
    }
  }
}

class _TechnicianCard extends StatelessWidget {
  final String requestId;
  final String technicianId;
  final Map<String, dynamic> data;
  final bool showLiveLocation;
  final bool allowChat;

  const _TechnicianCard({
    required this.requestId,
    required this.technicianId,
    required this.data,
    required this.showLiveLocation,
    required this.allowChat,
  });

  static const Color primaryColor = CustomerRequestTrackingPage.primaryColor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['technicianImageUrl']?.toString() ?? '';
    final phone = data['technicianPhone']?.toString() ?? '';
    final name = data['technicianName']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CustomerRequestTrackingPage.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'بيانات الفني',
            style: TextStyle(
              color: primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF15182A),
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          _row('اسم الفني', name.isEmpty ? 'غير متوفر' : name),
          _row('رقم الجوال', phone.isEmpty ? 'غير متوفر' : phone),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.phone),
              label: const Text('الاتصال بالفني'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/${_internationalPhone(phone)}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.chat),
              label: const Text('التواصل عبر واتساب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
          ],
          if (allowChat) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      requestId: requestId,
                      otherPersonName: name.isEmpty ? 'الفني' : name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.message),
              label: const Text('محادثة الفني'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
          if (showLiveLocation) ...[
            const SizedBox(height: 10),
            _LiveLocation(technicianId: technicianId),
          ],
        ],
      ),
    );
  }

  static String _internationalPhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('05')) {
      digits = '966${digits.substring(1)}';
    } else if (digits.startsWith('5')) {
      digits = '966$digits';
    }
    return digits;
  }

  static Widget _row(String title, String value) =>
      CustomerRequestTrackingPage._infoRow(title, value);
}

/// موقع الفني المباشر (متاح فقط أثناء الطلب المقبول حسب قواعد Firestore).
class _LiveLocation extends StatelessWidget {
  final String technicianId;

  const _LiveLocation({required this.technicianId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('technicians')
          .doc(technicianId)
          .snapshots(),
      builder: (context, snapshot) {
        final location = snapshot.data?.data();
        final lat = location?['latitude'];
        final lng = location?['longitude'];
        final hasLocation = lat is num && lng is num;

        if (!hasLocation) {
          return CustomerRequestTrackingPage._infoRow(
            'موقع الفني',
            snapshot.hasError ? 'تعذر تحميل الموقع' : 'بانتظار تحديث الموقع',
          );
        }

        return OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
            ),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.map),
          label: const Text('عرض موقع الفني على الخريطة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: CustomerRequestTrackingPage.primaryColor,
          ),
        );
      },
    );
  }
}
