import 'package:flutter/material.dart';

import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'games_screen.dart';
import 'growth_timeline_screen.dart';
import 'home_screen.dart';
import 'mypage_screen.dart';

/// 입양자 하단 내비게이션 뼈대: 홈 / 게임 / 타임라인 / 마이페이지.
/// `IndexedStack`으로 네 화면을 모두 유지해 탭을 전환해도 상태(스크롤 위치,
/// 불러온 데이터 등)가 초기화되지 않는다. 대신 홈/타임라인은 다른 탭에 다녀오는 동안
/// 데이터가 바뀔 수 있어(완성 신고, 새 일지 등) 탭 재진입 시 [RevalidatableState]로
/// 백그라운드 재조회 신호를 보낸다.
class AdopterShell extends StatefulWidget {
  const AdopterShell({super.key});

  @override
  State<AdopterShell> createState() => _AdopterShellState();
}

class _AdopterShellState extends State<AdopterShell> {
  static const _home = 0;
  static const _games = 1;
  static const _timeline = 2;
  static const _mypage = 3;

  int _tab = _home;

  final _homeKey = GlobalKey<RevalidatableState>();
  final _timelineKey = GlobalKey<RevalidatableState>();
  final _mypageKey = GlobalKey<RevalidatableState>();

  late final _screens = [
    HomeScreen(key: _homeKey),
    const GamesScreen(),
    GrowthTimelineScreen(key: _timelineKey),
    MypageScreen(key: _mypageKey),
  ];

  void _switchTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    switch (index) {
      case _home:
        _homeKey.currentState?.revalidate();
      case _timeline:
        _timelineKey.currentState?.revalidate();
      case _mypage:
        _mypageKey.currentState?.revalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x0A000000))),
        ),
        // 제스처 내비게이션을 쓰는 기기에서 하단 시스템 영역과 탭 터치 영역이
        // 겹치지 않도록 그만큼 아래로 밀어낸다(흰 배경/구분선은 이 영역까지 그대로 덮는다).
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '홈',
                  active: _tab == _home,
                  onTap: () => _switchTab(_home),
                ),
                _NavItem(
                  icon: Icons.sports_esports_outlined,
                  label: '게임',
                  active: _tab == _games,
                  onTap: () => _switchTab(_games),
                ),
                _NavItem(
                  icon: Icons.timeline,
                  label: '타임라인',
                  active: _tab == _timeline,
                  onTap: () => _switchTab(_timeline),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: '마이페이지',
                  active: _tab == _mypage,
                  onTap: () => _switchTab(_mypage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.badgeGreenText : const Color(0xFFB7B2A4);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (active)
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(height: 6),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.body(fontSize: 12, color: color).copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
