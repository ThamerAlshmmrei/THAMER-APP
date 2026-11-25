import 'package:material_ui/material_ui.dart';

import 'core/legal_notice.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'core/service_catalog.dart';
import 'services/image_storage_service.dart';

class TechnicianRegisterPage extends StatefulWidget {
  const TechnicianRegisterPage({super.key});

  @override
  State<TechnicianRegisterPage> createState() => _TechnicianRegisterPageState();
}

class _TechnicianRegisterPageState extends State<TechnicianRegisterPage> {
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
  void initState() {
    super.initState();

    // إذا كان الفني مسجلاً دخوله مسبقاً (مثل إعادة التقديم بعد الرفض)
    // نتخطى خطوة التحقق من الجوال.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.phoneNumber != null) {
      phoneVerified = true;
      phoneController.text = user.phoneNumber!;
    }
  }

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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر اختيار الصورة: $e')));
    }
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
          // التحقق التلقائي في أندرويد: نسجل الدخول مباشرة.
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            setState(() {
              loading = false;
              phoneVerified = true;
            });
          } catch (e) {
            if (!mounted) return;
            setState(() => loading = false);
          }
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

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      setState(() {
        loading = false;
        phoneVerified = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم التحقق من رقم الجوال')));

      // Next: technician details and approval request.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'رمز التحقق غير صحيح')),
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
        const SnackBar(content: Text('أكمل جميع الحقول المطلوبة')),
      );
      return;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(residenceId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رقم هوية أو إقامة صحيح من 10 أرقام'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.phoneNumber == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تحقق من رقم جوالك أولاً')));
      return;
    }

    setState(() => loading = true);

    try {
      final applicationRef = FirebaseFirestore.instance
          .collection('technicianApplications')
          .doc(user.uid);

      final existingApplication = await applicationRef.get();

      // يسمح بإعادة التقديم فقط إذا رُفض الطلب السابق.
      if (existingApplication.exists &&
          existingApplication.data()?['status'] != 'rejected') {
        if (!mounted) return;

        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لديك طلب انضمام مسبق قيد المراجعة')),
        );
        return;
      }

      final profileImageUrl = profileImage == null
          ? null
          : await ImageStorageService().uploadTechnicianProfileImage(
              image: profileImage!,
              userId: user.uid,
            );

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال طلبك للمراجعة')));

      // AuthGate يعرض صفحة حالة طلب الانضمام.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      appBar: AppBar(
        title: const Text('تسجيل فني'),
        backgroundColor: const Color(0xFF080B16),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.engineering, size: 75, color: primaryColor),
            const SizedBox(height: 25),
            const Text(
              'انضم إلى ثامر كفني',
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
              enabled: verificationId == null && !loading && !phoneVerified,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الجوال',
                hintText: '05XXXXXXXX',
                prefixIcon: Icon(Icons.phone_android),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (verificationId == null && !phoneVerified)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : sendCode,
                  child: const Text('إرسال رمز التحقق'),
                ),
              ),
            if (verificationId != null && !phoneVerified) ...[
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : verifyCode,
                  child: const Text('تحقق من الرمز'),
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
                'بيانات الفني',
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
                          ? 'إضافة صورة شخصية'
                          : 'تغيير الصورة',
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
                  labelText: 'الاسم الأول',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'اسم العائلة',
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
                  labelText: 'رقم الهوية / الإقامة',
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
                  labelText: 'البريد الإلكتروني (اختياري)',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                initialValue: specialization,
                dropdownColor: const Color(0xFF15182A),
                decoration: const InputDecoration(
                  labelText: 'تخصصك',
                  prefixIcon: Icon(Icons.engineering),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final service in ServiceCatalog.all)
                    DropdownMenuItem(
                      value: service.id,
                      child: Text(service.technicianTitle),
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
                    'إرسال طلب الانضمام',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const LegalNotice(),
            ],

            if (applicationSubmitted) ...[
              const SizedBox(height: 30),
              Icon(Icons.hourglass_top, color: primaryColor, size: 60),
              const SizedBox(height: 15),
              const Text(
                'طلبك قيد المراجعة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'بتقدر تستقبل الطلبات بعد اعتماد الإدارة.',
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
