import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM(Firebase Cloud Messaging) 기기 토큰을 가져오는 얇은 래퍼.
///
/// `google-services.json`이 Android에만 설정돼 있어, Android가 아닌 플랫폼
/// (web/windows 등)에서는 Firebase가 초기화되지 않으므로 항상 null을 반환한다.
class FcmService {
  Future<String?> getDeviceToken() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    await FirebaseMessaging.instance.requestPermission();
    return FirebaseMessaging.instance.getToken();
  }
}
