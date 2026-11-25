import 'package:cloud_functions/cloud_functions.dart';

/// إعدادات عامة للتطبيق في مكان واحد.
class AppConfig {
  AppConfig._();

  /// رابط موقع Firebase Hosting (تُنشر عليه صفحات docs/).
  static const String websiteUrl = 'https://thamer-e0fdd.web.app';

  static const String privacyPolicyUrl = '$websiteUrl/privacy.html';
  static const String termsUrl = '$websiteUrl/terms.html';
  static const String deleteAccountUrl = '$websiteUrl/delete-account.html';

  /// بريد الدعم الفني: اكتب بريدك هنا قبل النشر (يظهر في صفحة "حسابي").
  /// ونفس البريد اكتبه في ملفات docs/*.html مكان SUPPORT_EMAIL.
  static const String supportEmail = '';
}

/// Cloud Functions في نفس المنطقة المستخدمة في functions/index.js.
final FirebaseFunctions appFunctions = FirebaseFunctions.instanceFor(
  region: 'me-central2',
);
