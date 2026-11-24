import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'core/request_status.dart';
import 'core/service_catalog.dart';
import 'customer_request_tracking_page.dart';
import 'my_requests_page.dart';
import 'service_request_page.dart';
import 'services/notification_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color primaryColor = Color(0xFF20E0C0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'طلباتي',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyRequestsPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              Navigator.of(context).popUntil((route) => route.isFirst);
              await NotificationService.signOut();
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B16), Color(0xFF15182A), Color(0xFF080B16)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 10),
              const Icon(
                Icons.home_repair_service,
                color: primaryColor,
                size: 65,
              ),
              const SizedBox(height: 18),
              const Text(
                'THAMER APP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 35),
              const Text(
                'وش تحتاج؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اختر الخدمة وسنبحث لك عن أقرب فني',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 25),
              if (user != null) _ActiveRequestBanner(uid: user.uid),
              for (final service in ServiceCatalog.all) ...[
                serviceCard(context, service),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 20),
              const Text(
                'THAMER © 2026',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget serviceCard(BuildContext context, ServiceInfo service) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceRequestPage(serviceType: service.id),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF20283B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.5),
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Icon(service.icon, color: primaryColor, size: 44),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    service.description,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

/// يعرض الطلب الجاري (إن وجد) حتى يرجع له العميل بعد إغلاق التطبيق.
class _ActiveRequestBanner extends StatelessWidget {
  final String uid;

  const _ActiveRequestBanner({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('customerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        QueryDocumentSnapshot<Map<String, dynamic>>? active;
        for (final doc in docs) {
          if (RequestStatus.isActive(doc.data()['status'])) {
            active = doc;
            break;
          }
        }

        if (active == null) return const SizedBox.shrink();

        final data = active.data();
        final status = data['status'];
        final requestId = active.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Material(
            color: RequestStatus.color(status).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerRequestTrackingPage(requestId: requestId),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: RequestStatus.color(status),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طلب ${ServiceCatalog.jobNameOf(data['serviceType'])} جاري',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            RequestStatus.customerText(status),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
