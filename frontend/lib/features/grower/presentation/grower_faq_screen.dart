import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';

class _FaqItem {
  const _FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

const _faqItems = [
  _FaqItem(
    '일지는 얼마나 자주 작성해야 하나요?',
    '정해진 주기는 없지만, 입양자가 성장 과정을 꾸준히 지켜볼 수 있도록 며칠에 한 번씩 사진과 함께 '
        '작성해주시는 걸 권장해요. 사진을 올리면 비전 분석과 일러스트 변환까지 자동으로 이어집니다.',
  ),
  _FaqItem(
    '센서 값(온도·습도·조도)은 어떻게 측정해서 입력하나요?',
    '재배 공간에 설치된 온습도계·조도계를 확인한 뒤, 환경 점검 화면에서 값을 직접 입력하고 '
        '저장하면 됩니다. 저장 즉시 서버가 정상 범위인지 자동으로 판정해줘요.',
  ),
  _FaqItem(
    '"이상 감지"가 뜨면 어떻게 해야 하나요?',
    '어떤 값이 정상 범위를 벗어났는지 안내 문구를 먼저 확인해주세요. 함께 표시되는 진단 문구가 '
        '있다면 그 안내에 따라 조치하고, 상황이 계속되면 마이 탭의 "도움 요청하기"로 문의해주세요.',
  ),
  _FaqItem(
    '묘목 완성 신고는 언제 하나요?',
    '무화과가 다 자라 입양자에게 전달할 준비가 됐을 때 완성 신고를 해주세요. 신고하면 담당 '
        '입양자에게 자동으로 알림이 가고, 수령/기부를 선택할 수 있는 상태로 바뀝니다.',
  ),
  _FaqItem(
    '완성 신고 후에는 무엇을 해야 하나요?',
    '입양자가 수령 또는 기부 중 하나를 선택하면 재배자에게 다시 알림이 옵니다. 수령이면 방문 '
        '수령을 준비하고, 기부면 안내된 기부처로 전달할 준비를 해주시면 됩니다.',
  ),
  _FaqItem(
    '담당 묘목은 어떻게 배정되나요?',
    '입양자가 새로 무화과를 입양하면, 현재 재배 중인 묘목 수가 가장 적은 재배자에게 서버가 자동으로 '
        '배정해요. 별도로 신청하지 않아도 마이 탭의 담당 묘목 수에 자동으로 반영됩니다.',
  ),
  _FaqItem(
    '알림은 언제 오나요?',
    '담당 묘목의 입양자가 수령/기부를 선택하는 등 재배자가 바로 알아야 하는 시점에 푸시 알림이 '
        '와요. 다만 지금은 알림 종류를 따로 켜고 끄는 설정은 없어 모든 알림이 그대로 발송됩니다.',
  ),
];

/// 재배자 마이 탭 "FAQ"에서 진입. 자주 묻는 질문 7개를 아코디언으로 보여준다.
class GrowerFaqScreen extends StatelessWidget {
  const GrowerFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          itemCount: _faqItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _FaqCard(item: _faqItems[index]),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            item.question,
            style: AppTextStyles.body(
              fontSize: 14,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          expandedAlignment: Alignment.centerLeft,
          children: [
            Text(
              item.answer,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ).copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
