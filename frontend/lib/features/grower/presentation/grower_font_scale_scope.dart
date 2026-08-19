import 'package:flutter/material.dart';

import '../../../core/storage/grower_font_scale_storage.dart';
import '../../../core/storage/token_storage.dart';

/// 재배자 화면(`GrowerShell` 및 그 아래에서 push되는 모든 화면)에 저장된 글자 크기
/// 배율을 적용하는 wrapper.
///
/// 이 프로젝트는 `main.dart`의 `MaterialApp.routes`에 단일 루트 Navigator로 화면을
/// 전부 등록한다("중첩 라우터 없음") — `/grower/complete`, `/grower/faq` 같은 push
/// 화면들은 `GrowerShell`의 자손이 아니라 같은 레벨의 별도 라우트로 올라간다. 그래서
/// `GrowerShell.build()` 안에만 MediaQuery override를 두면 4탭(홈/일지/환경점검/마이)
/// 에는 적용되지만 push 화면에는 전혀 적용되지 않는다 — 이 문제를 피하려고 `main.dart`가
/// `/grower*` 라우트 엔트리마다 화면을 이 위젯으로 개별적으로 감싼다.
class GrowerFontScaleScope extends StatefulWidget {
  const GrowerFontScaleScope({super.key, required this.child});

  final Widget child;

  /// [GrowerSettingsDialog]에서 배율을 새로 저장한 직후 호출한다. 가장 가까운
  /// 조상 scope(=현재 라우트를 감싼 인스턴스)가 저장된 값을 다시 읽어 즉시 반영한다.
  /// `/grower`(`GrowerShell`)처럼 화면이 `IndexedStack`으로 계속 유지되는 라우트에서만
  /// 의미가 있다 — 다른 push 화면들은 다음 진입 시 새 인스턴스가 저장된 최신 값을
  /// 그대로 읽으므로 별도 갱신이 필요 없다.
  static Future<void> refresh(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_GrowerFontScaleScopeState>();
    return state?._load() ?? Future<void>.value();
  }

  @override
  State<GrowerFontScaleScope> createState() => _GrowerFontScaleScopeState();
}

class _GrowerFontScaleScopeState extends State<GrowerFontScaleScope> {
  double _scale = GrowerFontScaleStorage.defaultScale;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = await TokenStorage().readUserId();
    if (userId == null) return;
    final scale = await GrowerFontScaleStorage(userId: userId).getScale();
    if (mounted) setState(() => _scale = scale);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_scale)),
      child: widget.child,
    );
  }
}
