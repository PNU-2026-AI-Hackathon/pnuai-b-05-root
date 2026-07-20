import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/care_action_button.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/gauge_bar.dart';
import '../../../shared/widgets/pig_character.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/speech_bubble.dart';

/// 1f — 홈: 나의 무화과. mock 데이터로 표시하며 케어 액션 4종을 각 케어 화면으로 연결한다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _mockProgress = 0.6; // 3/5단계
  static const _mockStage = '3/5단계';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: AppColors.pink100, borderRadius: BorderRadius.circular(20)),
                child: Text('3일 동안 자리를 비웠더니...', style: AppTextStyles.body(fontSize: 14, color: AppColors.badgePinkText)),
              ),
              const SizedBox(height: 28),
              const FigTreeIllustration(width: 190),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SpeechBubble(text: '꿀꿀~ 내가 왔다!'),
                      const PigCharacter(width: 60),
                    ],
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
          Positioned(
            right: 14,
            top: 96,
            child: Column(
              children: [
                CareActionButton(
                  emoji: '💧',
                  label: '물주기',
                  onTap: () => Navigator.of(context).pushNamed('/adopter/care/water'),
                ),
                const SizedBox(height: 16),
                CareActionButton(
                  emoji: '🍃',
                  label: '영양제',
                  onTap: () => Navigator.of(context).pushNamed('/adopter/care/nutrient'),
                ),
                const SizedBox(height: 16),
                CareActionButton(
                  emoji: '☀️',
                  label: '햇빛',
                  onTap: () => Navigator.of(context).pushNamed('/adopter/care/sunlight'),
                ),
                const SizedBox(height: 16),
                CareActionButton(
                  emoji: '✂️',
                  label: '가지치기',
                  onTap: () => Navigator.of(context).pushNamed('/adopter/care/pruning'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Text('나의 무화과 🌱', style: AppTextStyles.title()),
                  const SizedBox(height: 12),
                  const GaugeBar(value: _mockProgress),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(_mockStage, style: AppTextStyles.body(fontSize: 12, color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 2),
                  Text('마지막 케어: 오늘', style: AppTextStyles.caption()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
