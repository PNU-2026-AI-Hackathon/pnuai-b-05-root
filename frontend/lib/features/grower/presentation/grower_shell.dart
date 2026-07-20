import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'grower_dashboard_screen.dart';
import 'grower_diary_screen.dart';
import 'grower_sensor_screen.dart';

/// 재배자 하단 내비게이션 뼈대: 홈(대시보드) / 일지 / 환경점검.
/// adopter_shell.dart와 동일한 패턴이되, 3탭 모두 실제 화면으로 전환된다.
class GrowerShell extends StatefulWidget {
  const GrowerShell({super.key});

  @override
  State<GrowerShell> createState() => _GrowerShellState();
}

class _GrowerShellState extends State<GrowerShell> {
  int _index = 0;

  static const _screens = [
    GrowerDashboardScreen(),
    GrowerDiaryScreen(),
    GrowerSensorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x0A000000))),
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: '홈',
              active: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _NavItem(
              icon: Icons.assignment_outlined,
              label: '일지',
              active: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
            _NavItem(
              icon: Icons.thermostat_outlined,
              label: '환경점검',
              active: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

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
            if (active) Container(width: 26, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.body(fontSize: 12, color: color)
                  .copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
