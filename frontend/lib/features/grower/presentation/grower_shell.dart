import 'package:flutter/material.dart';

import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import 'grower_dashboard_screen.dart';
import 'grower_mypage_screen.dart';
import 'grower_sensor_screen.dart';

/// 재배자 하단 내비게이션 뼈대: 홈(대시보드) / 일지 / 환경점검 / 마이.
/// `IndexedStack`으로 네 화면을 모두 유지해 탭을 전환해도 상태가 초기화되지 않는다.
/// 대신 홈/마이는 일지·환경점검 탭에 다녀오는 동안 통계가 바뀔 수 있어 탭 재진입 시
/// [RevalidatableState]로 백그라운드 재조회 신호를 보낸다.
class GrowerShell extends StatefulWidget {
  const GrowerShell({super.key});

  @override
  State<GrowerShell> createState() => _GrowerShellState();
}

class _GrowerShellState extends State<GrowerShell> {
  int _index = 0;

  final _dashboardKey = GlobalKey<RevalidatableState>();
  final _mypageKey = GlobalKey<RevalidatableState>();

  late final _screens = [
    GrowerDashboardScreen(key: _dashboardKey),
    const _DiaryTabPlaceholder(),
    const GrowerSensorScreen(),
    GrowerMypageScreen(key: _mypageKey),
  ];

  void _switchTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    switch (index) {
      case 0:
        _dashboardKey.currentState?.revalidate();
      case 3:
        _mypageKey.currentState?.revalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
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
                  active: _index == 0,
                  onTap: () => _switchTab(0),
                ),
                _NavItem(
                  icon: Icons.assignment_outlined,
                  label: '일지',
                  active: _index == 1,
                  onTap: () => _switchTab(1),
                ),
                _NavItem(
                  icon: Icons.thermostat_outlined,
                  label: '환경점검',
                  active: _index == 2,
                  onTap: () => _switchTab(2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: '마이',
                  active: _index == 3,
                  onTap: () => _switchTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 일지 탭 자리의 임시 플레이스홀더. 작성 폼(`GrowerDiaryWriteScreen`)이 이 탭 자체가 아니라
/// 별도 push 화면(`/grower/diary-write`)으로 옮겨가면서, 이 탭에 들어갈 실제 화면(묘목별
/// 일지 리스트)은 다음 단계에서 만든다.
class _DiaryTabPlaceholder extends StatelessWidget {
  const _DiaryTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '일지 화면을 준비하고 있어요',
              style: AppTextStyles.body(
                fontSize: 15,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
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
