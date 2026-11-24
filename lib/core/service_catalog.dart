import 'package:material_ui/material_ui.dart';

/// وصف خدمة واحدة في التطبيق (سباكة، كهرباء، مكيفات، غسالات).
///
/// المعرّف [id] هو القيمة المحفوظة في Firestore ويجب أن يطابق
/// القائمة الموجودة في firestore.rules و functions/index.js.
class ServiceInfo {
  final String id;
  final String title;
  final String technicianTitle;
  final String jobName;
  final String description;
  final IconData icon;

  /// سؤال نوع الجهاز وخياراته (للمكيفات والغسالات).
  final String? deviceQuestion;
  final List<String> deviceTypes;

  /// سؤال نوع المشكلة/العمل المطلوب وخياراته.
  final String? issueQuestion;
  final List<String> issueTypes;

  const ServiceInfo({
    required this.id,
    required this.title,
    required this.technicianTitle,
    required this.jobName,
    required this.description,
    required this.icon,
    this.deviceQuestion,
    this.deviceTypes = const [],
    this.issueQuestion,
    this.issueTypes = const [],
  });

  bool get hasDeviceDetails => deviceTypes.isNotEmpty && issueTypes.isNotEmpty;
}

class ServiceCatalog {
  ServiceCatalog._();

  static const ServiceInfo plumber = ServiceInfo(
    id: 'plumber',
    title: 'سباك',
    technicianTitle: 'فني سباكة',
    jobName: 'سباكة',
    description: 'خدمات السباكة المنزلية',
    icon: Icons.plumbing,
  );

  static const ServiceInfo electrician = ServiceInfo(
    id: 'electrician',
    title: 'كهربائي',
    technicianTitle: 'فني كهرباء',
    jobName: 'كهرباء',
    description: 'خدمات الكهرباء المنزلية',
    icon: Icons.electrical_services,
  );

  static const ServiceInfo ac = ServiceInfo(
    id: 'ac',
    title: 'فني مكيفات',
    technicianTitle: 'فني مكيفات',
    jobName: 'مكيفات',
    description: 'صيانة وتنظيف وتركيب المكيفات',
    icon: Icons.ac_unit,
    deviceQuestion: 'وش نوع المكيف؟',
    deviceTypes: ['سبليت', 'شباك', 'دولابي', 'كاسيت (سقفي)', 'مركزي'],
    issueQuestion: 'وش يحتاج المكيف؟',
    issueTypes: [
      'تنظيف وصيانة دورية',
      'تعبئة فريون',
      'لا يبرد',
      'تسريب ماء',
      'صوت مزعج',
      'لا يشتغل',
      'تركيب جديد',
      'فك ونقل',
    ],
  );

  static const ServiceInfo washingMachine = ServiceInfo(
    id: 'washing_machine',
    title: 'فني غسالات',
    technicianTitle: 'فني غسالات',
    jobName: 'غسالات',
    description: 'صيانة وتركيب الغسالات والنشافات',
    icon: Icons.local_laundry_service,
    deviceQuestion: 'وش نوع الغسالة؟',
    deviceTypes: [
      'أوتوماتيك تحميل أمامي',
      'أوتوماتيك تحميل علوي',
      'عادية (حوضين)',
      'غسالة ونشافة',
      'نشافة',
    ],
    issueQuestion: 'وش تحتاج الغسالة؟',
    issueTypes: [
      'لا تصرّف الماء',
      'لا تعصر أو لا تدور',
      'تسريب ماء',
      'لا تشتغل',
      'صوت أو اهتزاز عالي',
      'الباب لا يفتح أو لا يقفل',
      'تركيب وتوصيل',
      'صيانة عامة',
    ],
  );

  static const List<ServiceInfo> all = [
    plumber,
    electrician,
    ac,
    washingMachine,
  ];

  static ServiceInfo? byId(Object? id) {
    for (final service in all) {
      if (service.id == id) return service;
    }
    return null;
  }

  /// اسم الخدمة للعرض، مثل "سباكة" أو "مكيفات".
  static String jobNameOf(Object? id) => byId(id)?.jobName ?? '-';
}
