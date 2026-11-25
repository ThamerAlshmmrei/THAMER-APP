import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_gate.dart';
import 'core/app_config.dart';
import 'customer_register_page.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'technician_register_page.dart';

/// تشغيل التطبيق على محاكيات Firebase المحلية:
/// flutter run --dart-define=USE_FIREBASE_EMULATOR=true
/// ويمكن تحديد عنوان جهاز المحاكي:
/// --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.10
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

const String _emulatorHostOverride = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useFirebaseEmulator) {
    await _connectToEmulators();
  } else {
    await _activateAppCheck();
  }

  runApp(const MyApp());
}

/// App Check يتأكد أن الطلبات جاية من تطبيقك الأصلي فقط، ويحمي من
/// إرسال رسائل SMS وهمية على حسابك. في وضع التطوير يُستخدم مزود
/// التصحيح (Debug) ويُطبع رمزه في السجل لتضيفه في Firebase Console.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleDeviceCheckProvider()
          : const AppleDebugProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

Future<void> _connectToEmulators() async {
  final host = _emulatorHostOverride.isNotEmpty
      ? _emulatorHostOverride
      : (!kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost');

  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
  appFunctions.useFunctionsEmulator(host, 5000);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
}

const Color kPrimaryColor = Color(0xFF20E0C0);
const Color kBackgroundColor = Color(0xFF080B16);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thamer',
      scaffoldMessengerKey: NotificationService.messengerKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: kBackgroundColor,
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: kPrimaryColor,
          secondary: kPrimaryColor,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kPrimaryColor,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  String? verificationId;
  bool codeSent = false;
  bool loading = false;

  final Color primaryColor = const Color(0xFF20E0C0);

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    final phone = phoneController.text.trim();

    final normalizedPhone = phone.startsWith('05')
        ? '+966${phone.substring(1)}'
        : phone;

    if (!RegExp(r'^\+9665\d{8}$').hasMatch(normalizedPhone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل رقم جوال سعودي صحيح')));
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,

        verificationCompleted: (credential) async {
          await completePhoneLogin(credential);
        },

        verificationFailed: (e) {
          if (!mounted) return;

          setState(() => loading = false);

          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message ?? 'فشل التحقق')));
        },

        codeSent: (id, token) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            codeSent = true;
            loading = false;
          });
        },

        codeAutoRetrievalTimeout: (id) {
          verificationId = id;
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  Future<void> verifyCode() async {
    if (verificationId == null) return;

    final code = codeController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز التحقق المكون من 6 أرقام')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: code,
      );

      await completePhoneLogin(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'رمز التحقق غير صحيح')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  Future<void> completePhoneLogin(PhoneAuthCredential credential) async {
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = result.user;

      if (user == null) {
        throw Exception('تعذر تسجيل الدخول');
      }

      final db = FirebaseFirestore.instance;

      final userDoc = await db.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // AuthGate ينقل المستخدم تلقائياً لصفحته حسب نوع الحساب.
        return;
      }

      // فني قدّم طلب انضمام ولم يُعتمد بعد: AuthGate يعرض حالة الطلب.
      final application = await db
          .collection('technicianApplications')
          .doc(user.uid)
          .get();

      if (application.exists) return;

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد حساب مرتبط بهذا الرقم، أنشئ حساباً جديداً'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B16), Color(0xFF15182A), Color(0xFF080B16)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 35),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOGO

                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.blur_on,
                              color: primaryColor,
                              size: 48,
                            ),
                          ),

                          const SizedBox(height: 15),

                          Text(
                            'THAMER App',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 55),

                    const Text(
                      'أهلاً بعودتك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'سجّل دخولك برقم جوالك للمتابعة',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),

                    const SizedBox(height: 40),

                    const Text(
                      'رقم الجوال',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextFormField(
                      controller: phoneController,
                      enabled: !codeSent && !loading,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration(
                        '05XXXXXXXX',
                        Icons.phone_android,
                      ),
                    ),

                    if (codeSent) ...[
                      const SizedBox(height: 25),

                      const Text(
                        'رمز التحقق',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextFormField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration(
                          'أدخل الرمز المرسل برسالة SMS',
                          Icons.lock_outline,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // SIGN IN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : (codeSent ? verifyCode : sendCode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          codeSent ? 'تحقق وسجّل الدخول' : 'إرسال رمز التحقق',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // CREATE ACCOUNT
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'ما عندك حساب؟ ',
                            style: TextStyle(color: Colors.white60),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AccountTypePage(),
                                ),
                              );
                            },
                            child: const Text(
                              'إنشاء حساب',
                              style: TextStyle(
                                color: Color(0xFF20E0C0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    const Center(
                      child: Text(
                        'THAMER © 2026',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: const Color(0xFF20E0C0)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF20E0C0), width: 1.2),
      ),
    );
  }
}

class AccountTypePage extends StatelessWidget {
  const AccountTypePage({super.key});

  final Color primaryColor = const Color(0xFF20E0C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.blur_on, color: Color(0xFF20E0C0), size: 65),

              const SizedBox(height: 30),

              const Text(
                'اختر نوع الحساب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'كيف تحب تنضم إلى ثامر؟',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),

              const SizedBox(height: 45),

              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomerRegisterPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('حساب عميل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 65,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TechnicianRegisterPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.engineering),
                  label: const Text('حساب فني'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
