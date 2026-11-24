import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_page.dart';
class CustomerRequestTrackingPage extends StatelessWidget {
  final String requestId;

  const CustomerRequestTrackingPage({
    super.key,
    required this.requestId,
  });

  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color backgroundColor = Color(0xFF101525);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول')),
      );
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
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
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

          String statusText;

          switch (status) {
            case 'searching':
              statusText = 'نبحث عن فني قريب منك';
              break;
            case 'offered':
              statusText = 'تم إرسال الطلب إلى الفني، بانتظار رده';
              break;
            case 'accepted':
              statusText = 'تم قبول طلبك! الفني في طريقه إليك';
              break;
            case 'rejected':
              statusText = 'تم رفض الطلب، نبحث عن فني آخر';
              break;
            case 'no_technician_available':
              statusText = 'لا يوجد فني متاح حالياً';
              break;
            case 'waiting_customer_confirmation':
              statusText = 'الفني أنهى العمل، يرجى تأكيد الانتهاء';
              break;
            case 'completed':
              statusText = 'اكتملت الخدمة بنجاح';
              break;
            default:
              statusText = 'حالة الطلب: $status';
          }

          final technicianId = data['technicianId'];
          final technicianLatitude = data['technicianLatitude'];
final technicianLongitude = data['technicianLongitude'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20283B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection('technicians')
      .doc(technicianId.toString())
      .snapshots(),
  builder: (context, locationSnapshot) {
    final technicianLocation = locationSnapshot.data?.data();

    final lat = technicianLocation?['latitude'];
    final lng = technicianLocation?['longitude'];

    final hasLocation = lat is num && lng is num;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20283B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
  child: Column(
    children: [
      CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFF15182A),
        backgroundImage:
            (data['technicianImageUrl'] != null &&
                    data['technicianImageUrl'].toString().isNotEmpty)
                ? NetworkImage(
                    data['technicianImageUrl'].toString(),
                  )
                : null,
        child: (data['technicianImageUrl'] == null ||
                data['technicianImageUrl'].toString().isEmpty)
            ? const Icon(
                Icons.person,
                size: 55,
                color: Colors.white70,
              )
            : null,
      ),
      const SizedBox(height: 12),
    ],
  ),
),
          _infoRow(
            'اسم الفني',
            data['technicianName'] ?? 'غير متوفر',
          ),
          _infoRow(
            'رقم الجوال',
            data['technicianPhone'] ?? 'غير متوفر',
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final phone = data['technicianPhone']?.toString();
                if (phone == null || phone.isEmpty) return;

                await launchUrl(
                  Uri(scheme: 'tel', path: phone),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('الاتصال بالفني'),
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
              onPressed: () async {
                final phone = data['technicianPhone']?.toString();
                if (phone == null || phone.isEmpty) return;

                String internationalPhone =
                    phone.replaceAll(RegExp(r'[^0-9]'), '');

                if (internationalPhone.startsWith('05')) {
                  internationalPhone =
                      '966${internationalPhone.substring(1)}';
                } else if (internationalPhone.startsWith('5')) {
                  internationalPhone = '966$internationalPhone';
                }

                await launchUrl(
                  Uri.parse('https://wa.me/$internationalPhone'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('التواصل عبر واتساب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
          ),
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            requestId: requestId,
            otherPersonName:
                data['technicianName']?.toString() ?? 'الفني',
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
),

const SizedBox(height: 15),

          _infoRow(
            'حالة الموقع',
            locationSnapshot.hasError
                ? 'تعذر تحميل الموقع'
                : hasLocation
                    ? 'الموقع متاح'
                    : 'بانتظار تحديث الموقع',
          ),

          if (hasLocation) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                  );

                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('عرض موقع الفني'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  },
),
                      const Icon(
                        Icons.engineering,
                        color: primaryColor,
                        size: 55,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'رقم الطلب: $requestId',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'تفاصيل الطلب',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _infoRow(
                  'نوع الخدمة',
                  data['serviceType'] == 'plumber'
                      ? 'سباكة'
                      : 'كهرباء',
                ),

                _infoRow(
                  'مدة العمل',
                  '${data['durationMinutes'] ?? 0} دقيقة',
                ),

                _infoRow(
                  'الإجمالي',
                  '${data['totalPrice'] ?? 0} ريال',
                ),

                if (status == 'accepted' && technicianId != null) ...[
  const SizedBox(height: 25),

  const Text(
    'بيانات الفني',
    style: TextStyle(
      color: primaryColor,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),

  const SizedBox(height: 12),

  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF20283B),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(
          'اسم الفني',
          data['technicianName'] ?? 'غير متوفر',
        ),

        _infoRow(
          'رقم الجوال',
          data['technicianPhone'] ?? 'غير متوفر',
        ),

        const SizedBox(height: 15),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final phone = data['technicianPhone']?.toString();

              if (phone == null || phone.isEmpty) return;

              final uri = Uri(
                scheme: 'tel',
                path: phone,
              );

              await launchUrl(uri);
            },
            icon: const Icon(Icons.phone),
            label: const Text('الاتصال بالفني'),
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
    onPressed: () async {
      final phone = data['technicianPhone']?.toString();

      if (phone == null || phone.isEmpty) return;

      // تحويل الرقم السعودي إلى الصيغة الدولية
      String internationalPhone = phone.replaceAll(' ', '');

      if (internationalPhone.startsWith('05')) {
        internationalPhone =
            '966${internationalPhone.substring(1)}';
      } else if (internationalPhone.startsWith('+')) {
        internationalPhone = internationalPhone.substring(1);
      }

      final uri = Uri.parse(
        'https://wa.me/$internationalPhone',
      );

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    },
    icon: const Icon(Icons.chat),
    label: const Text('التواصل عبر واتساب'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
    ),
  ),
),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final lat = technicianLatitude;
              final lng = technicianLongitude;

              if (lat is! num || lng is! num) return;

              final uri = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
              );

              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.map),
            label: const Text('عرض موقع الفني'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
            ),
          ),
        ),
      ],
    ),
  ),
],

                if (status == 'waiting_customer_confirmation') ...[
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('requests')
                              .doc(requestId)
                              .update({
                            'status': 'completed',
                            'customerConfirmedAt':
                                FieldValue.serverTimestamp(),
                          });

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تأكيد اكتمال الخدمة'),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تعذر تأكيد الطلب: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('تأكيد انتهاء الخدمة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(15),
                      ),
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

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
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
}