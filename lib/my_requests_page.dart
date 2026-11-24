import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'core/pricing.dart';
import 'core/request_status.dart';
import 'core/service_catalog.dart';
import 'customer_request_tracking_page.dart';

/// سجل طلبات العميل.
class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: const Color(0xFF080B16),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('customerId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'تعذر تحميل الطلبات: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'ما عندك طلبات للحين',
                      style: TextStyle(color: Colors.white70, fontSize: 17),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final status = data['status'];
                    final service = ServiceCatalog.byId(data['serviceType']);
                    final createdAt = data['createdAt'];
                    final date = createdAt is Timestamp
                        ? _formatDate(createdAt.toDate())
                        : '';
                    final total = data['totalPrice'];

                    return ListTile(
                      tileColor: const Color(0xFF20283B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Icon(
                        service?.icon ?? Icons.build,
                        color: const Color(0xFF20E0C0),
                        size: 32,
                      ),
                      title: Text(
                        'طلب ${service?.jobName ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          date,
                          if (total is num) Pricing.format(total),
                        ].where((e) => e.isNotEmpty).join(' • '),
                      ),
                      trailing: Text(
                        RequestStatus.shortText(status),
                        style: TextStyle(
                          color: RequestStatus.color(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerRequestTrackingPage(requestId: doc.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
