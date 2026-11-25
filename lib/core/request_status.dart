import 'package:material_ui/material_ui.dart';

/// نصوص وألوان حالات الطلب في مكان واحد.
class RequestStatus {
  RequestStatus._();

  static const List<String> active = [
    'awaiting_payment',
    'searching',
    'offered',
    'rejected',
    'accepted',
    'waiting_customer_confirmation',
  ];

  /// الحالات التي يقدر العميل يلغي فيها الطلب.
  static const List<String> cancellable = [
    'awaiting_payment',
    'searching',
    'offered',
    'rejected',
    'no_technician_available',
  ];

  static bool isActive(Object? status) => active.contains(status);

  static String customerText(Object? status) {
    switch (status) {
      case 'awaiting_payment':
        return 'بانتظار إتمام الدفع';
      case 'searching':
        return 'نبحث عن فني قريب منك';
      case 'offered':
        return 'تم إرسال الطلب إلى الفني، بانتظار رده';
      case 'accepted':
        return 'تم قبول طلبك! الفني في طريقه إليك';
      case 'rejected':
        return 'نبحث لك عن فني آخر';
      case 'no_technician_available':
        return 'لا يوجد فني متاح حالياً';
      case 'waiting_customer_confirmation':
        return 'الفني أنهى العمل، يرجى تأكيد الانتهاء';
      case 'completed':
        return 'اكتملت الخدمة بنجاح';
      case 'cancelled':
        return 'تم إلغاء الطلب';
      default:
        return 'حالة الطلب: $status';
    }
  }

  static String shortText(Object? status) {
    switch (status) {
      case 'awaiting_payment':
        return 'بانتظار الدفع';
      case 'searching':
      case 'rejected':
        return 'جاري البحث';
      case 'offered':
        return 'بانتظار الفني';
      case 'accepted':
        return 'جاري التنفيذ';
      case 'waiting_customer_confirmation':
        return 'بانتظار تأكيدك';
      case 'no_technician_available':
        return 'لا يوجد فني';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return '$status';
    }
  }

  static Color color(Object? status) {
    switch (status) {
      case 'completed':
        return Colors.greenAccent;
      case 'cancelled':
      case 'no_technician_available':
        return Colors.redAccent;
      case 'waiting_customer_confirmation':
      case 'awaiting_payment':
        return Colors.orangeAccent;
      default:
        return const Color(0xFF20E0C0);
    }
  }

  static String paymentText(Object? paymentStatus) {
    switch (paymentStatus) {
      case 'paid':
        return 'مدفوع';
      case 'refunded':
        return 'تم استرجاع المبلغ';
      case 'refund_failed':
        return 'جاري استرجاع المبلغ';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return '-';
    }
  }
}
