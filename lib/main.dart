import 'services/firestore_services.dart';
import 'home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'technician_home_page.dart';
import 'package:my_first_app/technician_register_page.dart';
import 'package:my_first_app/admin_home_page.dart';
import 'package:my_first_app/customer_register_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);

  FirebaseFirestore.instance.useFirestoreEmulator(
    '10.0.2.2',
    8081,
  );

  FirebaseFunctions.instance.useFunctionsEmulator(
    '10.0.2.2',
    5000,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thamer ',
      theme: ThemeData.dark(),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool hidePassword = true;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أدخل رقم جوال سعودي صحيح')),
    );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'فشل التحقق')),
        );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $e')),
    );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $e')),
    );
  }
}
Future<void> completePhoneLogin(
  PhoneAuthCredential credential,
) async {
  try {
    final result = await FirebaseAuth.instance
        .signInWithCredential(credential);

    final user = result.user;

    if (user == null) {
      throw Exception('تعذر تسجيل الدخول');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    if (!userDoc.exists) {
      await FirebaseAuth.instance.signOut();

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد حساب مرتبط بهذا الرقم'),
        ),
      );
      return;
    }

    final role = userDoc.data()?['role'];

    Widget? destination;

    if (role == 'customer') {
      destination = const HomePage();
    } else if (role == 'technician') {
      destination = const TechnicianHomePage();
    } else if (role == 'admin') {
      destination = const AdminHomePage();
    }

    if (destination == null) {
      await FirebaseAuth.instance.signOut();

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('صلاحية الحساب غير معروفة'),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination!),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر تسجيل الدخول: $e')),
    );
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
            colors: [
              Color(0xFF080B16),
              Color(0xFF15182A),
              Color(0xFF080B16),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 35,
              ),
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
                              color: primaryColor.withValues(alpha:0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: primaryColor.withValues(alpha:0.4),
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
                      'Welcome Back.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Sign in to continue your experience.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 40),

                    const Text(
  'MOBILE NUMBER',
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
  style: const TextStyle(color: Colors.white),
  decoration: inputDecoration(
    '05XXXXXXXX',
    Icons.phone_android,
  ),
),

if (codeSent) ...[
  const SizedBox(height: 25),

  const Text(
    'VERIFICATION CODE',
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
      'Enter SMS Code',
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
  codeSent ? 'VERIFY & SIGN IN' : 'SEND VERIFICATION CODE',
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
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
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.white60,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Account creation will be added next.',
                                  ),
                                ),
                              );
                            },
                            child: TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
      builder: (context) =>
    const AccountTypePage(),
      ),
    );
  },
  child: const Text(
    'Create Account',
    style: TextStyle(
      color: Color(0xFF20E0C0),
      fontWeight: FontWeight.bold,
    ),
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

  InputDecoration inputDecoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white38,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF20E0C0),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha:0.06),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha:0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF20E0C0),
          width: 1.2,
        ),
      ),
    );
  }
}
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  bool hidePassword = true;
  bool hideConfirmPassword = true;
final phoneController = TextEditingController();
final nameController = TextEditingController();
final emailController = TextEditingController();
final passwordController = TextEditingController();
final confirmPasswordController = TextEditingController();
@override
void dispose() {
  phoneController.dispose();
  nameController.dispose();
  emailController.dispose();
  passwordController.dispose();
  confirmPasswordController.dispose();
  super.dispose();
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
            colors: [
              Color(0xFF080B16),
              Color(0xFF15182A),
              Color(0xFF080B16),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 35),

                  const Center(
                    child: Icon(
                      Icons.blur_on,
                      color: Color(0xFF20E0C0),
                      size: 55,
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Create Your\nAccount.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Join THAMER and start your experience.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Full Name
                  _inputField(
  hint: 'Full Name',
  icon: Icons.person_outline,
  controller: nameController,
),
                  const SizedBox(height: 18),

                  // Email
                  _inputField(
  hint: 'Email Address',
  icon: Icons.alternate_email,
  keyboard: TextInputType.emailAddress,
  controller: emailController,
),
                 const SizedBox(height: 18),

_inputField(
  hint: 'Phone Number (+966)',
  icon: Icons.phone_android,
  keyboard: TextInputType.phone,
  controller: phoneController,
),

                  // Password
                  _inputField(
                    hint: 'Password',
                    controller: passwordController,
                    icon: Icons.lock_outline,
                    obscure: hidePassword,
                    suffix: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Confirm Password
                  _inputField(
                    hint: 'Confirm Password',
                    controller: confirmPasswordController,
                    icon: Icons.lock_outline,
                    obscure: hideConfirmPassword,
                    suffix: IconButton(
                      icon: Icon(
                        hideConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          hideConfirmPassword =
                              !hideConfirmPassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Create Account Button
                 SizedBox(
  width: double.infinity,
  height: 58,
  child: ElevatedButton(
    onPressed: () async {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text;
      final confirmPassword = confirmPasswordController.text;
      final phone = phoneController.text.trim();

      if (name.isEmpty ||
          email.isEmpty ||
          password.isEmpty ||
          phone.isEmpty ||
          confirmPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all fields'),
          ),
        );
        return;
      }

      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
          ),
        );
        return;
      }

      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters'),
          ),
        );
        return;
      }

      try {
  final result = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(
    email: email,
    password: password,
  );

  final user = result.user;

  if (user == null) return;

  await user.updateDisplayName(name);

  // Save customer data in Firestore
  await FirestoreService().saveUser(
    uid: user.uid,
    name: name,
    email: email,
    phone: phoneController.text.trim(),
  );

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Account created successfully!'),
    ),
  );

  Navigator.pop(context);

} on FirebaseAuthException catch (e) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.message ?? 'Registration failed'),
    ),
  );

} catch (e) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error saving user data: $e')),
  );
}
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF20E0C0),
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    child: const Text(
      'CREATE ACCOUNT',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ),
  ),
),
                  const SizedBox(height: 25),

                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Already have an account? Sign In',
                        style: TextStyle(
                          color: Color(0xFF20E0C0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF20E0C0),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha:0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
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
              const Icon(
                Icons.blur_on,
                color: Color(0xFF20E0C0),
                size: 65,
              ),

              const SizedBox(height: 30),

              const Text(
                'Choose Account Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'How would you like to join THAMER?',
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
                        builder: (context) =>
    const CustomerRegisterPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('CUSTOMER ACCOUNT'),
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
                  label: const Text('TECHNICIAN ACCOUNT'),
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