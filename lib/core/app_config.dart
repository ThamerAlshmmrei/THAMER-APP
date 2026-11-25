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

  /// مفتاح ميسّر العام (Publishable key): يبدأ بـ pk_test_ للتجربة
  /// و pk_live_ للتشغيل الفعلي. هذا المفتاح آمن داخل التطبيق.
  /// (المفتاح السري sk_ لا يوضع هنا أبداً، مكانه Firebase Secrets.)
  /// يمكن تمريره وقت البناء: --dart-define=MOYASAR_PUBLISHABLE_KEY=pk_live_...
  static const String moyasarPublishableKey = String.fromEnvironment(
    'MOYASAR_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// معرف Apple Pay Merchant (مثل merchant.com.thamer.thamer).
  /// اتركه فارغاً لإخفاء زر Apple Pay حتى تفعّله في ميسّر و Xcode.
  static const String applePayMerchantId = String.fromEnvironment(
    'APPLE_PAY_MERCHANT_ID',
    defaultValue: '',
  );
}

/// Cloud Functions في نفس المنطقة المستخدمة في functions/index.js.
final FirebaseFunctions appFunctions = FirebaseFunctions.instanceFor(
  region: 'me-central2',
);
