import 'package:shared_preferences/shared_preferences.dart';

/// 재배자 화면 전용 글자 크기 배율. [CareInventoryStorage]와 동일하게
/// **계정(userId) 단위**로 분리해 저장한다.
///
/// [small](=1.0)은 기존 화면 기본 크기와 같아, 한 번도 설정을 바꾼 적 없는 계정은
/// 이전과 동일한 화면을 그대로 보게 된다.
class GrowerFontScaleStorage {
  GrowerFontScaleStorage({required this.userId});

  final String userId;

  static const _keyPrefix = 'pigfig.grower_font_scale.';

  static const double small = 1.0;
  static const double medium = 1.15;
  static const double large = 1.3;

  static const double defaultScale = small;

  Future<double> getScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_keyPrefix$userId') ?? defaultScale;
  }

  Future<void> setScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_keyPrefix$userId', scale);
  }
}
