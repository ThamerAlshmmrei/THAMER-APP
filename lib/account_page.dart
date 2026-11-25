import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/app_config.dart';
import 'services/notification_service.dart';

/// صفحة "حسابي": بيانات المستخدم، الشروط والخصوصية، الدعم،
/// تسجيل الخروج وحذف الحساب.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color cardColor = Color(0xFF20283B);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        backgroundColor: const Color(0xFF080B16),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (user != null) _ProfileHeader(uid: user.uid),
          const SizedBox(height: 18),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () => _open(AppConfig.privacyPolicyUrl),
          ),
          _tile(
            icon: Icons.description_outlined,
            title: 'الشروط والأحكام',
            onTap: () => _open(AppConfig.termsUrl),
          ),
          if (AppConfig.supportEmail.isNotEmpty)
            _tile(
              icon: Icons.support_agent,
              title: 'تواصل مع الدعم',
              subtitle: AppConfig.supportEmail,
              onTap: () => launchUrl(
                Uri(scheme: 'mailto', path: AppConfig.supportEmail),
              ),
            ),
          const SizedBox(height: 18),
          _tile(
            icon: Icons.logout,
            title: 'تسجيل الخروج',
            onTap: () async {
              Navigator.of(context).popUntil((route) => route.isFirst);
              await NotificationService.signOut();
            },
          ),
          _tile(
            icon: Icons.delete_forever,
            title: 'حذف الحساب',
            subtitle: 'حذف حسابك وبياناتك نهائياً',
            color: Colors.redAccent,
            onTap: () => confirmAndDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(String url) {
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          icon,
          color: color == Colors.white ? primaryColor : color,
        ),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_left, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}

/// تأكيد ثم حذف الحساب نهائياً عبر Cloud Function.
/// تُستخدم أيضاً من صفحة حالة طلب انضمام الفني.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('حذف الحساب نهائياً'),
      content: const Text(
        'بيتم حذف حسابك وبياناتك الشخصية ومحادثاتك، '
        'وما تقدر تسترجعها بعدين.\n\nمتأكد؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('تراجع'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'حذف نهائي',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await appFunctions.httpsCallable('deleteAccount').call<void>();

    navigator.popUntil((route) => route.isFirst);
    await NotificationService.signOut();

    messenger.showSnackBar(const SnackBar(content: Text('تم حذف حسابك')));
  } on FirebaseFunctionsException catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(e.message ?? 'تعذر حذف الحساب')),
    );
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('تعذر حذف الحساب: $e')));
  }
}

class _ProfileHeader extends StatelessWidget {
  final String uid;

  const _ProfileHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['name'] ?? '').toString();
        final phone =
            (data?['phone'] ??
                    FirebaseAuth.instance.currentUser?.phoneNumber ??
                    '')
                .toString();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AccountPage.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF15182A),
                child: Icon(Icons.person, color: AccountPage.primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'مستخدم ثامر' : name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
