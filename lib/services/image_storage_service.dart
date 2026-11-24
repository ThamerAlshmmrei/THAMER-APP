import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ImageStorageService {
  // يمكن إيقاف رفع الصور مؤقتاً عند البناء:
  // --dart-define=ENABLE_STORAGE=false
  static const bool storageEnabled = bool.fromEnvironment(
    'ENABLE_STORAGE',
    defaultValue: true,
  );

  Future<String?> uploadTechnicianProfileImage({
    required File image,
    required String userId,
  }) async {
    if (!storageEnabled) {
      return null;
    }

    try {
      final extension = image.path.split('.').last.toLowerCase();

      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw Exception('Unsupported image format'),
      };

      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('technician_profiles')
          .child(userId)
          .child(fileName);

      final metadata = SettableMetadata(contentType: contentType);

      final uploadTask = await storageRef.putFile(image, metadata);

      return await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('Image upload failed: ${e.message}');
    }
  }
}
