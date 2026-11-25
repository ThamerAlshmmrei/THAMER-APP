/// تسعير الطلبات.
///
/// أي تعديل هنا يجب أن يطابقه تعديل في دالة validAppFee داخل
/// firestore.rules، لأن القواعد تتحقق من نفس الحساب.
class Pricing {
  Pricing._();

  /// سعر دقيقة العمل للفني.
  static const double pricePerMinute = 1.5;

  /// نسبة رسوم التطبيق من أجرة العمل.
  static const int appFeePercent = 15;

  /// الحد الأدنى لرسوم التطبيق.
  static const double minAppFee = 5.0;

  static const int minMinutes = 5;
  static const int maxMinutes = 120;

  static double laborCost(int minutes) => minutes * pricePerMinute;

  /// 15% من أجرة العمل (بالهللة، مع التقريب للأسفل) وبحد أدنى 5 ريال.
  static double appFee(double laborCost) {
    final halalas = (laborCost * appFeePercent).floor();
    return halalas >= minAppFee * 100 ? halalas / 100.0 : minAppFee;
  }

  static double total({
    required double laborCost,
    required double appFee,
    double materialsCost = 0.0,
  }) => laborCost + appFee + materialsCost;

  /// المبلغ بالهللة كما تطلبه بوابة الدفع (1 ريال = 100 هللة).
  static int toHalalas(num riyals) => (riyals * 100).round();

  static String format(num value) => '${value.toStringAsFixed(2)} ريال';
}
