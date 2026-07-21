import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/data/auth_repository.dart';

/// 입양자/재배자 역할 선택 세그먼트 컨트롤 (로그인/회원가입 화면 공용).
class RoleToggle extends StatelessWidget {
  const RoleToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E4D8),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          _tab(UserRole.adopter, '🐷 입양자'),
          _tab(UserRole.grower, '🧑‍🌾 재배자'),
        ],
      ),
    );
  }

  Widget _tab(UserRole role, String label) {
    final active = role == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(23),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: 15,
              color: active ? AppColors.badgePinkText : const Color(0xFF9B9686),
            ).copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
