import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'app_config';
  static const String _androidDocId = 'android';

  static Future<String> getAndroidDownloadUrl({
    required String fallbackUrl,
  }) async {
    try {
      final doc = await _db.collection(_collection).doc(_androidDocId).get();
      if (!doc.exists) return fallbackUrl;

      final data = doc.data();
      if (data == null) return fallbackUrl;

      final dynamic value = data['downloadUrl'];
      if (value == null) return fallbackUrl;

      final url = value.toString().trim();
      if (url.isEmpty) return fallbackUrl;

      return url;
    } catch (_) {
      return fallbackUrl;
    }
  }
}

