import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/grower_repository.dart';
import 'grower_complete_screen.dart';

/// `/grower/seedling-analysis` route argument.
class GrowerSeedlingAnalysisArgs {
  const GrowerSeedlingAnalysisArgs({
    required this.seedlingId,
    required this.adopterId,
    required this.status,
  });

  final int seedlingId;
  final int adopterId;
  final SeedlingStatus status;
}

/// 묘목 한 그루의 분석 화면(YOLO 비전 이력/센서 이상 이력 등)의 최소 뼈대 — 실제 내용은
/// 다음 단계에서 채운다. 홈 탭이 대시보드에서 "선반 뷰"로 바뀌면서 재배중 묘목의
/// "완성 신고하기" 진입점이 사라지지 않도록, 그 진입점만 여기 임시로 연결해둔다.
class GrowerSeedlingAnalysisScreen extends StatelessWidget {
  const GrowerSeedlingAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments
            as GrowerSeedlingAnalysisArgs;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  '무화과 #${args.seedlingId} 분석 화면 준비 중',
                  style: AppTextStyles.body(fontSize: 15),
                ),
              ),
            ),
            if (args.status == SeedlingStatus.growing)
              PigFigButton.primary(
                label: '완성 신고하기',
                onPressed: () => Navigator.of(context).pushNamed(
                  '/grower/complete',
                  arguments: GrowerCompleteArgs(
                    seedlingId: args.seedlingId,
                    seedlingName: '무화과 #${args.seedlingId}',
                    adopterName: '입양자 #${args.adopterId}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
