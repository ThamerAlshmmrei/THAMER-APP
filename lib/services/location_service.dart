import 'package:geolocator/geolocator.dart';

class LocationService {

  // جلب الموقع الحالي مرة واحدة
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('فعّل خدمة الموقع GPS في جهازك');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('لم تسمح للتطبيق باستخدام الموقع');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'صلاحية الموقع مرفوضة نهائياً، فعّلها من إعدادات التطبيق',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // متابعة الموقع بشكل مباشر
  Stream<Position> getLocationStream() async* {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('فعّل خدمة الموقع GPS في جهازك');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('صلاحية الموقع غير متاحة');
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    yield* Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
  }
}