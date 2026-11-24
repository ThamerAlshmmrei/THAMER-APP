import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerRegisterPage extends StatefulWidget {
  const CustomerRegisterPage({super.key});

  @override
  State<CustomerRegisterPage> createState() => _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends State<CustomerRegisterPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();

  String? verificationId;
  bool loading = false;

  final Color primaryColor = const Color(0xFF20E0C0);

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل الاسم الأول واسم العائلة ورقم الجوال'),
        ),
      );
      return;
    }

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
          await completeRegistration(credential);
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
            loading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم إرسال رمز التحقق')));
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

      await completeRegistration(credential);
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
          .showSnackBar(SnackBar(content: Text('خطأ في التسجيل: $e')));
    }
  }

  Future<void> completeRegistration(PhoneAuthCredential credential) async {
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = result.user;
      if (user == null) {
        throw Exception('تعذر إنشاء الحساب');
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final existingUser = await userRef.get();

      if (existingUser.exists) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الرقم مسجل مسبقاً، سجّل الدخول')),
        );
        return;
      }

      final firstName = firstNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final email = emailController.text.trim();

      await userRef.set({
        'uid': user.uid,
        'firstName': firstName,
        'lastName': lastName,
        'name': '$firstName $lastName',
        'email': email,
        'phone': user.phoneNumber,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إنشاء حسابك بنجاح')));

      // الرجوع للبداية: AuthGate يفتح الصفحة الرئيسية للعميل.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      appBar: AppBar(
        title: const Text('تسجيل عميل جديد'),
        backgroundColor: const Color(0xFF080B16),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.person_outline, size: 70, color: primaryColor),
            const SizedBox(height: 25),

            TextField(
              controller: firstNameController,
              enabled: verificationId == null && !loading,
              decoration: fieldDecoration('الاسم الأول', Icons.person),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: lastNameController,
              enabled: verificationId == null && !loading,
              decoration: fieldDecoration('اسم العائلة', Icons.person_outline),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: phoneController,
              enabled: verificationId == null && !loading,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: fieldDecoration(
                'رقم الجوال (05XXXXXXXX)',
                Icons.phone_android,
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: emailController,
              enabled: verificationId == null && !loading,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDecoration(
                'البريد الإلكتروني (اختياري)',
                Icons.email_outlined,
              ),
            ),

            const SizedBox(height: 22),

            if (verificationId == null)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading ? null : sendCode,
                  child: const Text('إرسال رمز التحقق'),
                ),
              ),

            if (verificationId != null) ...[
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration('رمز التحقق', Icons.lock_outline),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading ? null : verifyCode,
                  child: const Text('تحقق وأنشئ الحساب'),
                ),
              ),
            ],

            if (loading) ...[
              const SizedBox(height: 20),
              CircularProgressIndicator(color: primaryColor),
            ],
          ],
        ),
      ),
    );
  }
}
