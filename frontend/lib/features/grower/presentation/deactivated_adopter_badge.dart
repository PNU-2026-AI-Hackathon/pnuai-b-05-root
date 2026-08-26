import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';

/// 담당 묘목의 입양자가 회원탈퇴(소프트 삭제, `is_active=False`)한 경우 재배자 화면에
/// 붙는 배지. 탈퇴해도 묘목·일지는 그대로 유지되고 재배정도 하지 않으므로, 재배자에게
/// "이 입양자는 더 이상 앱을 쓰지 않는다"는 정보만 전달한다. 오류 상태가 아니라 정보라
/// 경고(빨강)가 아닌 중립 그레이 톤(`dotInactive`/`textMuted`)을 쓴다. 공용
/// [StatusBadge]를 그대로 감싸(재배중/완료 배지와 같은 위젯) 라벨·색만 고정한다 —
/// 일지 탭 묘목 카드·묘목 분석·완성 신고 세 화면이 공유한다.
class DeactivatedAdopterBadge extends StatelessWidget {
  const DeactivatedAdopterBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(
      label: '탈퇴한 계정',
      background: AppColors.dotInactive,
      textColor: AppColors.textMuted,
      pill: false,
    );
  }
}
