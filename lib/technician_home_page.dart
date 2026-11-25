import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/location_service.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_page.dart';
import 'chat_page.dart';
import 'technician_wallet_page.dart';
import 'core/pricing.dart';
import 'core/service_catalog.dart';

class TechnicianHomePage extends StatefulWidget {
  const TechnicianHomePage({super.key});

  @override
  State<TechnicianHomePage> createState() => _TechnicianHomePageState();
}

class _TechnicianHomePageState extends State<TechnicianHomePage> {
  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color backgroundColor = Color(0xFF101525);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _requestTrackingSubscription;

  StreamSubscription<Position>? _locationSubscription;

  String? _trackingRequestId;
  // تحديث موقع الفني الحالي
  Future<void> updateTechnicianLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final position = await LocationService().getCurrentLocation();

      await _db.collection('technicians').doc(user.uid).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تحديث موقعك بنجاح')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تحديث الموقع: $e')));
    }
  }

  // تغيير حالة توفر الفني
  Future<void> toggleTechnicianAvailability() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final technicianRef = _db.collection('technicians').doc(user.uid);

      final snapshot = await technicianRef.get();

      if (!snapshot.exists) {
        throw Exception('حساب الفني غير مسجل في قاعدة البيانات');
      }
      final currentRequestId = snapshot.data()?['currentRequestId'];

      if (currentRequestId != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لديك طلب مرتبط، لا يمكن تغيير حالة التوفر حاليًا'),
          ),
        );

        return;
      }

      final currentAvailability = snapshot.data()?['available'] == true;

      // إذا كان متاحاً، نحوله إلى غير متاح
      if (currentAvailability) {
        await technicianRef.update({'available': false});

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أصبحت غير متاح لاستقبال الطلبات')),
        );

        return;
      }

      // قبل تفعيل التوفر، نحدد موقع الفني ونحفظه
      final position = await LocationService().getCurrentLocation();

      await technicianRef.update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'available': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أصبحت متاحاً لاستقبال الطلبات')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تغيير الحالة: $e')));
    }
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      final Map<String, dynamic> updates = {'status': status};

      if (status == 'accepted') {
        updates['acceptedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'rejected') {
        updates['rejectedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'waiting_customer_confirmation') {
        updates['technicianCompletedAt'] = FieldValue.serverTimestamp();
      }

      await _db.collection('requests').doc(requestId).update(updates);

      if (!mounted) return;

      String message;

      switch (status) {
        case 'accepted':
          message = 'تم قبول الطلب';
          break;
        case 'rejected':
          message = 'تم رفض الطلب';
          break;
        case 'waiting_customer_confirmation':
          message = 'تم إرسال طلب تأكيد انتهاء العمل للعميل';
          break;
        default:
          message = 'تم تحديث الطلب';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تحديث الطلب: $e')));
    }
  }

  // مراقبة الطلب المقبول وتشغيل التتبع عند الحاجة
  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _requestTrackingSubscription = _db
        .collection('requests')
        .where('technicianId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            startLocationTracking(snapshot.docs.first.id);
          } else {
            stopLocationTracking();
          }
        });
  }

  // تشغيل بث الموقع بعد قبول الطلب
  void startLocationTracking(String requestId) {
    if (_trackingRequestId == requestId && _locationSubscription != null) {
      return;
    }

    stopLocationTracking();
    _trackingRequestId = requestId;

    _locationSubscription = LocationService().getLocationStream().listen(
      (position) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || _trackingRequestId != requestId) {
          return;
        }

        try {
          await _db.collection('technicians').doc(user.uid).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'locationUpdatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Location update error: $e');
        }
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
        stopLocationTracking();
      },
    );
  }

  // إيقاف التتبع
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _trackingRequestId = null;
  }

  // تنظيف الاشتراكات عند إغلاق الشاشة
  @override
  void dispose() {
    _requestTrackingSubscription?.cancel();
    stopLocationTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        title: const Text('لوحة الفني'),
        actions: [
          IconButton(
            tooltip: 'محفظتي',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TechnicianWalletPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'حسابي',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B16), Color(0xFF15182A), Color(0xFF080B16)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أهلاً بك في THAMER',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'طلبات الخدمة الموجهة إليك',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 14),
                _AvailabilityBadge(uid: user.uid),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: updateTechnicianLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('تحديث موقعي'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: toggleTechnicianAvailability,
                        icon: const Icon(Icons.work),
                        label: const Text('تغيير التوفر'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('requests')
                        .where('technicianId', isEqualTo: user.uid)
                        .where(
                          'status',
                          whereIn: [
                            'offered',
                            'accepted',
                            'waiting_customer_confirmation',
                          ],
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'تعذر تحميل الطلبات',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }

                      final requests = snapshot.data?.docs ?? [];

                      if (requests.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_outline,
                                color: primaryColor,
                                size: 65,
                              ),
                              SizedBox(height: 18),
                              Text(
                                'لا توجد طلبات جديدة حالياً',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final doc = requests[index];
                          final data = doc.data();

                          final status = data['status'];

                          final customerName =
                              data['customerName'] ?? 'غير متوفر';

                          final customerPhone =
                              data['customerPhone'] ?? 'غير متوفر';

                          final customerLatitude = data['customerLatitude'];

                          final customerLongitude = data['customerLongitude'];

                          final serviceType = ServiceCatalog.jobNameOf(
                            data['serviceType'],
                          );

                          final deviceType = data['deviceType'];
                          final issueType = data['issueType'];
                          final description = (data['problemDescription'] ?? '')
                              .toString();
                          final withMaterials =
                              data['requestType'] ==
                              'technician_with_materials';
                          final laborCost = data['laborCost'];

                          final duration = data['durationMinutes'] ?? 0;

                          final totalPrice = data['totalPrice'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF20283B),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'طلب $serviceType',
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (deviceType != null)
                                  _detail('نوع الجهاز', '$deviceType'),
                                if (issueType != null)
                                  _detail('المطلوب', '$issueType'),
                                _detail(
                                  'نوع الطلب',
                                  withMaterials
                                      ? 'فني مع توفير المواد'
                                      : 'فني فقط',
                                ),
                                if (description.isNotEmpty)
                                  _detail('الوصف', description),
                                _detail('مدة العمل', '$duration دقيقة'),
                                _detail(
                                  'أجرتك',
                                  laborCost is num
                                      ? Pricing.format(laborCost)
                                      : '-',
                                ),
                                _detail(
                                  'إجمالي ما يدفعه العميل',
                                  totalPrice is num
                                      ? Pricing.format(totalPrice)
                                      : '-',
                                ),
                                if (status == 'waiting_customer_confirmation')
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      'بانتظار تأكيد العميل لانتهاء العمل',
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 15),

                                if (status == 'accepted') ...[
                                  const Divider(color: Colors.white24),

                                  const Text(
                                    'بيانات العميل',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    'اسم العميل: $customerName',
                                    style: const TextStyle(color: Colors.white),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    'رقم الجوال: $customerPhone',
                                    style: const TextStyle(color: Colors.white),
                                  ),

                                  const SizedBox(height: 8),

                                  const SizedBox(height: 12),

                                  if (customerPhone != 'غير متوفر') ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => launchUrl(
                                          Uri(
                                            scheme: 'tel',
                                            path: customerPhone.toString(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.phone),
                                        label: const Text('الاتصال بالعميل'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        if (customerLatitude is! num ||
                                            customerLongitude is! num) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'موقع العميل غير متوفر حاليًا',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final uri = Uri.parse(
                                          'https://www.google.com/maps/dir/?api=1&destination=$customerLatitude,$customerLongitude',
                                        );

                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                      icon: const Icon(Icons.directions),
                                      label: const Text('الاتجاهات إلى العميل'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatPage(
                                              requestId: doc.id,
                                              otherPersonName: customerName,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.message),
                                      label: const Text('محادثة العميل'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),

                                if (status == 'offered') ...[
                                  const Text(
                                    'لديك دقيقتان للرد قبل تحويل الطلب لفني آخر',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => updateRequestStatus(
                                            doc.id,
                                            'accepted',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text('قبول'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => updateRequestStatus(
                                            doc.id,
                                            'rejected',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('رفض'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                if (status == 'accepted')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => updateRequestStatus(
                                        doc.id,
                                        'waiting_customer_confirmation',
                                      ),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('إنهاء العمل'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.all(14),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(color: Colors.white60),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// يوضح للفني هل هو متاح لاستقبال الطلبات أم لا.
class _AvailabilityBadge extends StatelessWidget {
  final String uid;

  const _AvailabilityBadge({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('technicians')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final available = data?['available'] == true;
        final busy = data?['currentRequestId'] != null;
        final service = ServiceCatalog.byId(data?['serviceType']);

        final String text;
        final Color color;

        if (busy) {
          text = 'لديك طلب جاري';
          color = Colors.orangeAccent;
        } else if (available) {
          text = 'متاح لاستقبال الطلبات';
          color = Colors.greenAccent;
        } else {
          text = 'غير متاح حالياً';
          color = Colors.redAccent;
        }

        return Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (service != null)
              Text(
                service.technicianTitle,
                style: const TextStyle(color: Colors.white60),
              ),
          ],
        );
      },
    );
  }
}
