import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:material_ui/material_ui.dart';

/// يسجل جهاز المستخدم لاستقبال الإشعارات ويحفظ الرمز في Firestore
/// حتى تستطيع Cloud Functions إرسال إشعار الطلبات الجديدة وتحديثاتها.
class NotificationService {
  NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static String? _registeredUid;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

  static DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// يُستدعى بعد التأكد من وجود ملف المستخدم في users.
  static Future<void> registerForUser(String uid) async {
    if (_registeredUid == uid) return;
    _registeredUid = uid;

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // الخادم (firebase-admin) يرسل عبر رمز FCM، لذلك نستخدم getToken.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) {
        await _userRef(uid).update({'fcmToken': token});
      }

      await _tokenRefreshSubscription?.cancel();
      // ignore: deprecated_member_use
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((
        newToken,
      ) async {
        final current = FirebaseAuth.instance.currentUser;
        if (current == null || current.uid != uid) return;
        try {
          await _userRef(uid).update({'fcmToken': newToken});
        } catch (e) {
          debugPrint('FCM token refresh save failed: $e');
        }
      });

      await _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;

        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              [
                notification.title,
                notification.body,
              ].whereType<String>().join('\n'),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      });
    } catch (e) {
      // في iOS يفشل getToken إذا لم يُضبط مفتاح APNs في Firebase بعد.
      debugPrint('Notification registration failed: $e');
    }
  }

  /// تسجيل الخروج مع حذف رمز الإشعارات من حساب المستخدم.
  static Future<void> signOut() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && _registeredUid == user.uid) {
      try {
        await _userRef(user.uid).update({'fcmToken': null});
      } catch (e) {
        debugPrint('Clearing FCM token failed: $e');
      }
    }

    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _registeredUid = null;

    await FirebaseAuth.instance.signOut();
  }
}
