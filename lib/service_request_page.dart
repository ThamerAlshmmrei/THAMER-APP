import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'core/pricing.dart';
import 'core/service_catalog.dart';
import 'customer_request_tracking_page.dart';
import 'services/firestore_services.dart';
import 'services/location_service.dart';

class ServiceRequestPage extends StatefulWidget {
  final String serviceType;

  const ServiceRequestPage({super.key, required this.serviceType});

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color cardColor = Color(0xFF20283B);

  int durationMinutes = Pricing.minMinutes;
  bool isSending = false;

  String requestType = 'technician_only';
  String? deviceType;
  String? issueType;

  final TextEditingController problemController = TextEditingController();

  ServiceInfo get service =>
      ServiceCatalog.byId(widget.serviceType) ?? ServiceCatalog.plumber;

  double get laborCost => Pricing.laborCost(durationMinutes);
  double get appFee => Pricing.appFee(laborCost);
  double get totalPrice => Pricing.total(laborCost: laborCost, appFee: appFee);

  @override
  void dispose() {
    problemController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('سجل الدخول أولاً');
      return;
    }

    if (service.hasDeviceDetails) {
      if (deviceType == null) {
        _showMessage(service.deviceQuestion ?? 'اختر نوع الجهاز');
        return;
      }
      if (issueType == null) {
        _showMessage(service.issueQuestion ?? 'اختر المطلوب');
        return;
      }
    } else if (problemController.text.trim().isEmpty) {
      _showMessage('اكتب وصف المشكلة أو العمل المطلوب');
      return;
    }

    setState(() => isSending = true);

    try {
      final position = await LocationService().getCurrentLocation();

      final requestId = await FirestoreService().createServiceRequest(
        customerId: user.uid,
        serviceType: service.id,
        durationMinutes: durationMinutes,
        requestType: requestType,
        problemDescription: problemController.text.trim(),
        deviceType: service.hasDeviceDetails ? deviceType : null,
        issueType: service.hasDeviceDetails ? issueType : null,
        customerLatitude: position.latitude,
        customerLongitude: position.longitude,
      );

      if (!mounted) return;

      _showMessage('تم إرسال طلبك بنجاح، نبحث لك عن أقرب فني');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerRequestTrackingPage(requestId: requestId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('تعذر إرسال الطلب: $e');
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101525),
      appBar: AppBar(
        title: Text('طلب ${service.title}'),
        backgroundColor: const Color(0xFF101525),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  if (service.hasDeviceDetails) ...[
                    sectionTitle(service.deviceQuestion!),
                    const SizedBox(height: 12),
                    choiceWrap(
                      options: service.deviceTypes,
                      selected: deviceType,
                      onSelected: (value) => setState(() => deviceType = value),
                    ),
                    const SizedBox(height: 24),
                    sectionTitle(service.issueQuestion!),
                    const SizedBox(height: 12),
                    choiceWrap(
                      options: service.issueTypes,
                      selected: issueType,
                      onSelected: (value) => setState(() => issueType = value),
                    ),
                    const SizedBox(height: 24),
                  ],
                  sectionTitle('وش تحتاج من الفني؟'),
                  const SizedBox(height: 14),
                  requestOption(
                    value: 'technician_only',
                    title: 'فني فقط',
                    description: 'عندي المواد أو أحتاج إصلاح مشكلة',
                    icon: Icons.handyman,
                  ),
                  const SizedBox(height: 12),
                  requestOption(
                    value: 'technician_with_materials',
                    title: 'فني مع توفير المواد',
                    description: 'أحتاج الفني يوفر المواد أو قطع الغيار',
                    icon: Icons.inventory_2,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    service.hasDeviceDetails
                        ? 'تفاصيل إضافية (اختياري)'
                        : 'وصف المشكلة أو العمل المطلوب',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: problemController,
                    maxLines: 3,
                    maxLength: 1000,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _hintForService(),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  sectionTitle('حدد مدة العمل'),
                  const SizedBox(height: 14),
                  Text(
                    '$durationMinutes دقيقة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: primaryColor,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: durationMinutes.toDouble(),
                    min: Pricing.minMinutes.toDouble(),
                    max: Pricing.maxMinutes.toDouble(),
                    divisions: Pricing.maxMinutes - Pricing.minMinutes,
                    activeColor: primaryColor,
                    inactiveColor: Colors.white24,
                    label: '$durationMinutes دقيقة',
                    onChanged: (value) {
                      setState(() => durationMinutes = value.round());
                    },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5 دقائق', style: TextStyle(color: Colors.white60)),
                      Text(
                        '120 دقيقة',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        priceRow(
                          'أجرة العمل (${Pricing.pricePerMinute} ريال/دقيقة)',
                          Pricing.format(laborCost),
                        ),
                        const SizedBox(height: 12),
                        priceRow('رسوم الخدمة', Pricing.format(appFee)),
                        const Divider(color: Colors.white24, height: 25),
                        priceRow(
                          'الإجمالي',
                          Pricing.format(totalPrice),
                          isTotal: true,
                        ),
                        if (requestType == 'technician_with_materials') ...[
                          const SizedBox(height: 12),
                          const Text(
                            'قيمة المواد تُتفق عليها مع الفني حسب الفاتورة.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSending ? null : sendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'إرسال الطلب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hintForService() {
    switch (service.id) {
      case 'ac':
        return 'مثلاً: عدد المكيفات، الدور، آخر مرة تنظف...';
      case 'washing_machine':
        return 'مثلاً: ماركة الغسالة، رسالة خطأ تظهر على الشاشة...';
      default:
        return 'مثلاً: تسريب ماء أو تركيب فيش...';
    }
  }

  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 21,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget choiceWrap({
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: selected == option,
            onSelected: (_) => onSelected(option),
            selectedColor: primaryColor,
            backgroundColor: cardColor,
            labelStyle: TextStyle(
              color: selected == option ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: selected == option ? primaryColor : Colors.white24,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }

  Widget requestOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = requestType == value;

    return InkWell(
      onTap: () => setState(() => requestType = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 30),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? primaryColor : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget priceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isTotal ? primaryColor : Colors.white70,
              fontSize: isTotal ? 19 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? primaryColor : Colors.white,
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
