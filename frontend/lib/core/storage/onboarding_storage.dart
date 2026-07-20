import 'package:shared_preferences/shared_preferences.dart';

/// 온보딩(최초 실행 안내) 노출 여부 로컬 저장소.
class OnboardingStorage {
  static const _seenKey = 'pigfig.onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
