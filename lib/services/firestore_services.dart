import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save customer information
  Future<void> saveUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'customer',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  // Create a new service request
  Future<String> createServiceRequest({
  required String customerId,
  required String serviceType,
  required int durationMinutes,
  required List<Map<String, dynamic>> materials,
  required double laborCost,
  required double appFee,
  required double materialsCost,
  required String requestType,
  required String problemDescription,
  required double customerLatitude,
required double customerLongitude,
}) async {
  final requestRef = _db.collection('requests').doc();

  await requestRef.set({
    'requestId': requestRef.id,
    'customerId': customerId,
    'technicianId': null,
    'serviceType': serviceType,
    'customerLatitude': customerLatitude,
'customerLongitude': customerLongitude,
    'requestType': requestType,
    'problemDescription': problemDescription,
    'durationMinutes': durationMinutes,
    'materials': materials,
    'laborCost': laborCost,
    'appFee': appFee,
    'materialsCost': materialsCost,
    'totalPrice': laborCost + appFee + materialsCost,
    'status': 'searching',
    'createdAt': FieldValue.serverTimestamp(),
  });

  return requestRef.id;
}

  // Save technician information
  Future<void> saveTechnician({
    required String uid,
    required String name,
    required String phone,
    required String serviceType,
    required double latitude,
    required double longitude,
    String? imageUrl,
  }) async {
    await _db.collection('technicians').doc(uid).set({
      'uid': uid,
      'name': name,
      'phone': phone,
      'serviceType': serviceType,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'available': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}