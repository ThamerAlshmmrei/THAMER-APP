import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_home_page.dart';
import 'core/service_catalog.dart';
import 'home_page.dart';
import 'main.dart';
import 'services/notification_service.dart';
import 'technician_home_page.dart';
import 'technician_register_page.dart';

/// نقطة الدخول: يحدد الصفحة المناسبة حسب حالة تسجيل الدخول ونوع الحساب،
/// ويبقي المستخدم مسجلاً بعد إغلاق التطبيق وفتحه.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;

        if (user == null) return const LoginPage();

        return _RoleRouter(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _RoleRouter extends StatelessWidget {
  final String uid;

  const _RoleRouter({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return _ErrorScreen(message: '${userSnapshot.error}');
        }

        if (!userSnapshot.hasData) return const _SplashScreen();

        final userData = userSnapshot.data!.data();

        if (userData != null) {
          NotificationService.registerForUser(uid);

          switch (userData['role']) {
            case 'customer':
              return const HomePage();
            case 'technician':
              return const TechnicianHomePage();
            case 'admin':
              return const AdminHomePage();
            default:
              return const _ErrorScreen(message: 'صلاحية الحساب غير معروفة');
          }
        }

        // لا يوجد ملف مستخدم: قد يكون فنياً ينتظر اعتماد طلبه.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: db.collection('technicianApplications').doc(uid).snapshots(),
          builder: (context, applicationSnapshot) {
            if (applicationSnapshot.hasError) return const LoginPage();
            if (!applicationSnapshot.hasData) return const _SplashScreen();

            final application = applicationSnapshot.data!.data();

            if (application == null) {
              // مستخدم بدأ التسجيل ولم يكمله.
              return const LoginPage();
            }

            return TechnicianApplicationStatusPage(application: application);
          },
        );
      },
    );
  }
}

class TechnicianApplicationStatusPage extends StatelessWidget {
  final Map<String, dynamic> application;

  const TechnicianApplicationStatusPage({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application['status'];
    final service = ServiceCatalog.byId(application['specialization']);

    final IconData icon;
    final String title;
    final String message;

    switch (status) {
      case 'rejected':
        icon = Icons.cancel_outlined;
        title = 'لم يتم قبول طلبك';
        message = 'تقدر تراجع بياناتك وتعيد التقديم مرة ثانية.';
        break;
      case 'approved':
        icon = Icons.verified;
        title = 'تم قبول طلبك';
        message = 'جاري تجهيز حسابك...';
        break;
      default:
        icon = Icons.hourglass_top;
        title = 'طلبك قيد المراجعة';
        message = 'بتقدر تستقبل الطلبات مباشرة بعد اعتماد الإدارة.';
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, color: kPrimaryColor, size: 80),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 15),
              ),
              if (service != null) ...[
                const SizedBox(height: 12),
                Text(
                  'التخصص: ${service.technicianTitle}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 35),
              if (status == 'rejected')
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TechnicianRegisterPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة التقديم'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: NotificationService.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.blur_on, color: kPrimaryColor, size: 70),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 60),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: NotificationService.signOut,
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
