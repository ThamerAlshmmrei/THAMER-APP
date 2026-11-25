import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../core/pricing.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // إنشاء طلب خدمة جديد
  Future<String> createServiceRequest({
    required String customerId,
    required String serviceType,
    required int durationMinutes,
    required String requestType,
    required String problemDescription,
    required double customerLatitude,
    required double customerLongitude,
    String? deviceType,
    String? issueType,
  }) async {
    final requestRef = _db.collection('requests').doc();

    final laborCost = Pricing.laborCost(durationMinutes);
    final appFee = Pricing.appFee(laborCost);
    const materialsCost = 0.0;

    await requestRef.set({
      'requestId': requestRef.id,
      'customerId': customerId,
      'technicianId': null,
      'serviceType': serviceType,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'requestType': requestType,
      'problemDescription': problemDescription,
      'deviceType': ?deviceType,
      'issueType': ?issueType,
      'durationMinutes': durationMinutes,
      'materials': <Map<String, dynamic>>[],
      'laborCost': laborCost,
      'appFee': appFee,
      'materialsCost': materialsCost,
      'totalPrice': Pricing.total(
        laborCost: laborCost,
        appFee: appFee,
        materialsCost: materialsCost,
      ),
      'status': 'awaiting_payment',
      'paymentStatus': 'unpaid',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return requestRef.id;
  }

  /// يطلب من السيرفر التحقق من الدفعة عند ميسّر وبدء البحث عن فني.
  Future<void> confirmPayment({
    required String requestId,
    required String paymentId,
  }) async {
    await appFunctions.httpsCallable('confirmPayment').call<void>({
      'requestId': requestId,
      'paymentId': paymentId,
    });
  }

  // إلغاء الطلب من العميل قبل قبول الفني
  Future<void> cancelRequest(String requestId) {
    return _db.collection('requests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // إعادة البحث عن فني بعد عدم توفر أحد
  Future<void> retryRequest(String requestId) {
    return _db.collection('requests').doc(requestId).update({
      'status': 'searching',
      'retriedAt': FieldValue.serverTimestamp(),
    });
  }

  // تأكيد العميل انتهاء الخدمة
  Future<void> confirmCompletion(String requestId) {
    return _db.collection('requests').doc(requestId).update({
      'status': 'completed',
      'customerConfirmedAt': FieldValue.serverTimestamp(),
    });
  }
}
