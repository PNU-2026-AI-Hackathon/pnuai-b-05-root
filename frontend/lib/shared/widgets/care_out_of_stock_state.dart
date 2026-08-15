import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pigfig_button.dart';

/// 케어 아이템(물주기/영양제/돼지먹이) 보유 개수가 0일 때 케어 화면 본문에
/// 보여주는 안내. 실제 게임 탭으로 딥링크하지 않고 가벼운 안내만 한다 —
/// `AdopterShell`의 `IndexedStack` 탭에 외부에서 특정 탭으로 진입시키는 기능이
/// 없고, 게임 보상이 아직 이 개수를 채워주지도 않는다(다음 단계에서 연동 예정).
class CareOutOfStockState extends StatelessWidget {
  const CareOutOfStockState({
    super.key,
    required this.emoji,
    required this.itemLabel,
  });

  /// 안내 상단에 크게 보여줄 이모지 (예: '💧').
  final String emoji;

  /// 문구에 들어갈 아이템 이름 (예: '물').
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              '보유한 $itemLabel(이)가 없어요',
              style: AppTextStyles.title(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              '게임 탭에서 아이템을 모아보세요 🎮',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PigFigButton.outline(
                label: '닫기',
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('게임 탭에서 아이템을 모아보세요 🎮')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
