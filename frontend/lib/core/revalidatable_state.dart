import 'package:flutter/widgets.dart';

/// `IndexedStack`으로 상태를 유지하는 탭 화면이 이 State를 상속하면, 탭을 벗어났다
/// 다시 들어왔을 때 Shell이 `GlobalKey`로 [revalidate]를 직접 호출해 최신 데이터를
/// 백그라운드로 다시 불러오게 할 수 있다(stale-while-revalidate).
///
/// [revalidate] 구현 시 지켜야 할 규칙:
/// - 기존에 화면에 보여주고 있던 데이터를 지우거나 로딩 스피너로 가리면 안 된다.
/// - 새 데이터가 도착하면 조용히 교체한다.
/// - 호출이 실패해도 기존 데이터를 그대로 유지한다(에러 문구를 새로 띄우지 않음).
abstract class RevalidatableState<T extends StatefulWidget> extends State<T> {
  Future<void> revalidate();
}
