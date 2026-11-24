import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_services.dart';
import 'services/location_service.dart';
import 'customer_request_tracking_page.dart';

class ServiceRequestPage extends StatefulWidget {
  final String serviceType;

  const ServiceRequestPage({
    super.key,
    required this.serviceType,
  });

  @override
  State<ServiceRequestPage> createState() =>
      _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  static const Color primaryColor = Color(0xFF20E0C0);

  int durationMinutes = 5;
  bool isSending = false;

  String requestType = 'technician_only';

  final TextEditingController problemController =
      TextEditingController();

  final double pricePerMinute = 1.5;
  final double appFee = 5.0;

  double get laborCost => durationMinutes * pricePerMinute;
  double get totalPrice => laborCost + appFee;

  @override
  void dispose() {
    problemController.dispose();
    super.dispose();
  }

  Future<void> sendRequest() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سجل الدخول أولاً')),
    );
    return;
  }

  if (problemController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اكتب وصف المشكلة أو العمل المطلوب')),
    );
    return;
  }

  setState(() => isSending = true);

  try {
    final position =
    await LocationService().getCurrentLocation();

final requestId =
    await FirestoreService().createServiceRequest(
  customerId: user.uid,
  serviceType: widget.serviceType,
  durationMinutes: durationMinutes,
  materials: [],
  laborCost: laborCost,
  appFee: appFee,
  materialsCost: 0.0,
  requestType: requestType,
  problemDescription: problemController.text.trim(),

  customerLatitude: position.latitude,
  customerLongitude: position.longitude,
);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إرسال طلبك بنجاح. رقم الطلب: $requestId'),
      ),
    );

    Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => CustomerRequestTrackingPage(
      requestId: requestId,
    ),
  ),
);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر إرسال الطلب: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => isSending = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final title =
        widget.serviceType == 'plumber' ? 'السباكة' : 'الكهرباء';

    return Scaffold(
      backgroundColor: const Color(0xFF101525),
      appBar: AppBar(
        title: Text('طلب خدمة $title'),
        backgroundColor: const Color(0xFF101525),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'وش تحتاج من الفني؟',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

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
              description: 'أحتاج الفني يوفر المواد المطلوبة',
              icon: Icons.inventory_2,
            ),

            const SizedBox(height: 22),

            const Text(
              'وصف المشكلة أو العمل المطلوب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: problemController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثلاً: تسريب ماء أو تركيب فيش...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF20283B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'حدد مدة العمل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

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
              min: 5,
              max: 120,
              divisions: 115,
              activeColor: primaryColor,
              inactiveColor: Colors.white24,
              label: '$durationMinutes دقيقة',
              onChanged: (value) {
                setState(() {
                  durationMinutes = value.round();
                });
              },
            ),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 دقائق',
                    style: TextStyle(color: Colors.white60)),
                Text('120 دقيقة',
                    style: TextStyle(color: Colors.white60)),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF20283B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  priceRow(
                    'أجرة العمل',
                    '${laborCost.toStringAsFixed(2)} ريال',
                  ),
                  const SizedBox(height: 12),
                  priceRow(
                    'رسوم التطبيق',
                    '${appFee.toStringAsFixed(2)} ريال',
                  ),
                  const Divider(color: Colors.white24, height: 25),
                  priceRow(
                    'الإجمالي',
                    '${totalPrice.toStringAsFixed(2)} ريال',
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const Spacer(),

            ElevatedButton(
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
                  ? const CircularProgressIndicator()
                  : const Text(
                      'إرسال الطلب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
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
      onTap: () {
        setState(() {
          requestType = value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF20283B),
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
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? primaryColor : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget priceRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? primaryColor : Colors.white70,
            fontSize: isTotal ? 19 : 15,
            fontWeight:
                isTotal ? FontWeight.bold : FontWeight.normal,
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