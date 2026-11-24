import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color backgroundColor = Color(0xFF080B16);

  final FirebaseFirestore db = FirebaseFirestore.instance;

  final Set<String> processingIds = {};

  Future<void> approveTechnician(
    String applicantId,
    Map<String, dynamic> data,
  ) async {
    if (processingIds.contains(applicantId)) return;

    setState(() => processingIds.add(applicantId));

    try {
      final batch = db.batch();

      final userRef = db.collection('users').doc(applicantId);
      final technicianRef =
          db.collection('technicians').doc(applicantId);
      final applicationRef =
          db.collection('technicianApplications').doc(applicantId);

      batch.set(userRef, {
        'uid': applicantId,
        'name': '${data['firstName']} ${data['lastName']}',
'firstName': data['firstName'],
'lastName': data['lastName'],
'residenceId': data['residenceId'],
        'email': data['email'],
        'phone': data['phoneNumber'],
        'role': 'technician',
        'profileImageUrl': data['profileImageUrl'],
        'createdAt': FieldValue.serverTimestamp(),
      });

     batch.set(technicianRef, {
  'uid': applicantId,
  'available': false,
  'serviceType': data['specialization'],
  'profileImageUrl': data['profileImageUrl'],
  'latitude': null,
  'longitude': null,
  'locationUpdatedAt': null,
});

      batch.update(applicationRef, {
        'status': 'approved',
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الفني وتفعيل حسابه بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر قبول الفني: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => processingIds.remove(applicantId));
      }
    }
  }

  Future<void> rejectTechnician(String applicantId) async {
    if (processingIds.contains(applicantId)) return;

    setState(() => processingIds.add(applicantId));

    try {
      await db
          .collection('technicianApplications')
          .doc(applicantId)
          .update({'status': 'rejected'});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض طلب الفني')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفض الطلب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => processingIds.remove(applicantId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        title: const Text('THAMER Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.of(context).popUntil(
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('technicianApplications')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل الطلبات: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          final applications = snapshot.data?.docs ?? [];

          if (applications.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد طلبات فنيين معلقة حالياً',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final doc = applications[index];
              final data = doc.data();
              final busy = processingIds.contains(doc.id);

              return Card(
                color: const Color(0xFF20283B),
                margin: const EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'طلب انضمام فني',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
  child: CircleAvatar(
    radius: 48,
    backgroundColor: const Color(0xFF15182A),
    backgroundImage:
        (data['profileImageUrl'] != null &&
                data['profileImageUrl'].toString().isNotEmpty)
            ? NetworkImage(data['profileImageUrl'].toString())
            : null,
    child: (data['profileImageUrl'] == null ||
            data['profileImageUrl'].toString().isEmpty)
        ? const Icon(
            Icons.person,
            size: 55,
            color: Colors.white70,
          )
        : null,
  ),
),
const SizedBox(height: 14),
                      _info(
  'الاسم',
  '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
),
                      _info('رقم الجوال', data['phoneNumber']),
                      _info('رقم الإقامة', data['residenceId']),
                      _info(
                        'التخصص',
                        data['specialization'] == 'plumber'
                            ? 'سباكة'
                            : 'كهرباء',
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: busy
                                  ? null
                                  : () => approveTechnician(
                                        doc.id,
                                        data,
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('قبول'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: busy
                                  ? null
                                  : () => rejectTechnician(doc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('رفض'),
                            ),
                          ),
                        ],
                      ),
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _info(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        '$title: ${value ?? '-'}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
    );
  }
}