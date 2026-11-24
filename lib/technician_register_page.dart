import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'services/image_storage_service.dart';

class TechnicianRegisterPage extends StatefulWidget {
  const TechnicianRegisterPage({super.key});

  @override
  State<TechnicianRegisterPage> createState() =>
      _TechnicianRegisterPageState();
}

class _TechnicianRegisterPageState
    extends State<TechnicianRegisterPage> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
final firstNameController = TextEditingController();
final lastNameController = TextEditingController();
final residenceIdController = TextEditingController();
final emailController = TextEditingController();

String? specialization;
File? profileImage;
final ImagePicker imagePicker = ImagePicker();

bool phoneVerified = false;
bool applicationSubmitted = false;

  String? verificationId;
  bool loading = false;

  final primaryColor = const Color(0xFF20E0C0);

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    firstNameController.dispose();
lastNameController.dispose();
residenceIdController.dispose();
emailController.dispose();
    super.dispose();
  }
Future<void> pickProfileImage() async {
  try {
    final XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1000,
    );

    if (pickedFile == null) return;

    setState(() {
      profileImage = File(pickedFile.path);
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error selecting image: $e')),
    );
  }
}
  Future<void> sendCode() async {
    final phone = phoneController.text.trim();

    final normalizedPhone = phone.startsWith('05')
        ? '+966${phone.substring(1)}'
        : phone;

    if (!RegExp(r'^\+9665\d{8}$').hasMatch(normalizedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid Saudi mobile number'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: (credential) async {
          if (mounted) {
            setState(() => loading = false);
          }
          // Automatic verification may happen on Android.
          // Account setup will be handled in the next step.
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

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      setState(() {
  loading = false;
  phoneVerified = true;
  });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone verified successfully'),
        ),
      );

      // Next: technician details and approval request.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Invalid code')),
      );
    }
  }
Future<void> submitTechnicianApplication() async {
  final firstName = firstNameController.text.trim();
final lastName = lastNameController.text.trim();
final residenceId = residenceIdController.text.trim();
final email = emailController.text.trim();

  if (firstName.isEmpty ||
    lastName.isEmpty ||
    residenceId.isEmpty ||
    specialization == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please complete all required fields'),
      ),
    );
    return;
  }

  if (!RegExp(r'^\d{10}$').hasMatch(residenceId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enter a valid 10-digit ID or Iqama number'),
      ),
    );
    return;
  }

  final user = FirebaseAuth.instance.currentUser;

  if (user == null || user.phoneNumber == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please verify your phone first')),
    );
    return;
  }

  setState(() => loading = true);

  try {
    final profileImageUrl = profileImage == null
    ? null
    : await ImageStorageService().uploadTechnicianProfileImage(
        image: profileImage!,
        userId: user.uid,
      );
    final applicationRef = FirebaseFirestore.instance
        .collection('technicianApplications')
        .doc(user.uid);

    final existingApplication = await applicationRef.get();

    if (existingApplication.exists) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already submitted an application'),
        ),
      );
      return;
    }

    await applicationRef.set({
  'uid': user.uid,
  'firstName': firstName,
  'lastName': lastName,
  'residenceId': residenceId,
  'phoneNumber': user.phoneNumber,
  'email': email,
  'specialization': specialization,
  'profileImageUrl': profileImageUrl,
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
});

    if (!mounted) return;

    setState(() {
      loading = false;
      applicationSubmitted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your application has been submitted for review'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error submitting application: $e')),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      appBar: AppBar(
        title: const Text('Technician Registration'),
        backgroundColor: const Color(0xFF080B16),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.engineering, size: 75, color: primaryColor),
            const SizedBox(height: 25),
            const Text(
              'Join THAMER as a Technician',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 35),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              enabled: verificationId == null && !loading,
              decoration: const InputDecoration(
                labelText: 'Saudi Mobile Number',
                hintText: '05XXXXXXXX',
                prefixIcon: Icon(Icons.phone_android),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (verificationId == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : sendCode,
                  child: const Text('SEND VERIFICATION CODE'),
                ),
              ),
            if (verificationId != null) ...[
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'SMS Verification Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : verifyCode,
                  child: const Text('VERIFY CODE'),
                ),
              ),
            ],
            if (loading) ...[
              const SizedBox(height: 20),
              CircularProgressIndicator(color: primaryColor),
            ],
            if (phoneVerified && !applicationSubmitted) ...[
  const SizedBox(height: 30),

  const Divider(color: Colors.white24),

  const SizedBox(height: 20),

  const Text(
    'Technician Information',
    style: TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
  ),
GestureDetector(
  onTap: pickProfileImage,
  child: Column(
    children: [
      CircleAvatar(
        radius: 55,
        backgroundColor: const Color(0xFF15182A),
        backgroundImage: profileImage != null
            ? FileImage(profileImage!)
            : null,
        child: profileImage == null
            ? Icon(
                Icons.add_a_photo,
                size: 35,
                color: primaryColor,
              )
            : null,
      ),
      const SizedBox(height: 10),
      Text(
        profileImage == null
            ? 'Add Profile Photo'
            : 'Change Profile Photo',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),

const SizedBox(height: 20),


 TextField(
  controller: firstNameController,
  style: const TextStyle(color: Colors.white),
  decoration: const InputDecoration(
    labelText: 'First Name',
    prefixIcon: Icon(Icons.person_outline),
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 18),

TextField(
  controller: lastNameController,
  style: const TextStyle(color: Colors.white),
  decoration: const InputDecoration(
    labelText: 'Last Name',
    prefixIcon: Icon(Icons.person_outline),
    border: OutlineInputBorder(),
  ),
),

  const SizedBox(height: 18),
TextField(
  controller: residenceIdController,
  keyboardType: TextInputType.number,
  maxLength: 10,
  style: const TextStyle(color: Colors.white),
  decoration: const InputDecoration(
    labelText: 'Residence ID (Iqama)',
    prefixIcon: Icon(Icons.badge_outlined),
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 18),

  TextField(
    controller: emailController,
    keyboardType: TextInputType.emailAddress,
    style: const TextStyle(color: Colors.white),
    decoration: const InputDecoration(
      labelText: 'Email Address (Optional)',
      prefixIcon: Icon(Icons.email_outlined),
      border: OutlineInputBorder(),
    ),
  ),

  const SizedBox(height: 18),

  DropdownButtonFormField<String>(
    value: specialization,
    dropdownColor: const Color(0xFF15182A),
    decoration: const InputDecoration(
      labelText: 'Your Specialization',
      prefixIcon: Icon(Icons.engineering),
      border: OutlineInputBorder(),
    ),
    items: const [
      DropdownMenuItem(
        value: 'plumber',
        child: Text('Plumber'),
      ),
      DropdownMenuItem(
        value: 'electrician',
        child: Text('Electrician'),
      ),
    ],
    onChanged: (value) {
      setState(() {
        specialization = value;
      });
    },
  ),

  const SizedBox(height: 25),

  SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: loading ? null : submitTechnicianApplication,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
      ),
      child: const Text(
        'SUBMIT APPLICATION',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  ),
],

if (applicationSubmitted) ...[
  const SizedBox(height: 30),
  Icon(Icons.hourglass_top, color: primaryColor, size: 60),
  const SizedBox(height: 15),
  const Text(
    'Your application is under review',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  const SizedBox(height: 10),
  const Text(
    'You will be able to work after admin approval.',
    textAlign: TextAlign.center,
    style: TextStyle(color: Colors.white60),
  ),
],
          ],
        ),
      ),
    );
  }
}