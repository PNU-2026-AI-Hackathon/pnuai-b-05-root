import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'home_screen.dart';
import 'mypage_screen.dart';

/// 입양자 하단 내비게이션 뼈대: 홈 / 게임 / 마이페이지.
/// 게임은 이번 범위 밖이라 탭하면 안내만 띄우고, 홈/마이페이지는 실제로 탭이 전환된다.
class AdopterShell extends StatefulWidget {
  const AdopterShell({super.key});

  @override
  State<AdopterShell> createState() => _AdopterShellState();
}

class _AdopterShellState extends State<AdopterShell> {
  static const _home = 0;
  static const _mypage = 1;

  int _tab = _home;

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == _mypage ? const MypageScreen() : const HomeScreen(),
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
              active: _tab == _home,
              onTap: () => setState(() => _tab = _home),
            ),
            _NavItem(
              icon: Icons.sports_esports_outlined,
              label: '게임',
              active: false,
              onTap: _showComingSoon,
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: '마이페이지',
              active: _tab == _mypage,
              onTap: () => setState(() => _tab = _mypage),
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
