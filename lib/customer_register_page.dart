import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerRegisterPage extends StatefulWidget {
  const CustomerRegisterPage({super.key});

  @override
  State<CustomerRegisterPage> createState() =>
      _CustomerRegisterPageState();
}

class _CustomerRegisterPageState
    extends State<CustomerRegisterPage> {
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
          content: Text('Please enter your first name, last name and phone'),
        ),
      );
      return;
    }

    final normalizedPhone = phone.startsWith('05')
        ? '+966${phone.substring(1)}'
        : phone;

    if (!RegExp(r'^\+9665\d{8}$').hasMatch(normalizedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Saudi mobile number')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Verification failed')),
          );
        },
        codeSent: (id, token) {
          if (!mounted) return;
          setState(() {
            verificationId = id;
            loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code sent')),
          );
        },
        codeAutoRetrievalTimeout: (id) {
          verificationId = id;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> verifyCode() async {
    if (verificationId == null) return;

    final code = codeController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
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
        SnackBar(content: Text(e.message ?? 'Invalid code')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e')),
      );
    }
  }

  Future<void> completeRegistration(
    PhoneAuthCredential credential,
  ) async {
    try {
      final result = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final user = result.user;
      if (user == null) {
        throw Exception('Unable to create account');
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
          const SnackBar(
            content: Text('This phone number already has an account. Please sign in.'),
          ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer account created successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
        title: const Text('Customer Registration'),
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
              decoration: fieldDecoration('First Name', Icons.person),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: lastNameController,
              enabled: verificationId == null && !loading,
              decoration: fieldDecoration('Last Name', Icons.person_outline),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: phoneController,
              enabled: verificationId == null && !loading,
              keyboardType: TextInputType.phone,
              decoration: fieldDecoration(
                'Mobile Number (05XXXXXXXX)',
                Icons.phone_android,
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: emailController,
              enabled: verificationId == null && !loading,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDecoration(
                'Email Address (Optional)',
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
                  child: const Text('SEND VERIFICATION CODE'),
                ),
              ),

            if (verificationId != null) ...[
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  'SMS Verification Code',
                  Icons.lock_outline,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading ? null : verifyCode,
                  child: const Text('VERIFY & CREATE ACCOUNT'),
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