import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/diary_repository.dart';
import '../data/grower_repository.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

/// 시분초를 뗀 날짜만 남긴다. 달력 그리드의 날짜 매칭/맵 키로 쓴다.
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// 담당 묘목 하나의 일지 한 건을 캘린더가 다루기 쉬운 형태로 묶는다. 선택한 날짜의
/// 요약에 "묘목 #{seedlingId}"를 보여주려면 어느 묘목의 일지인지 함께 알아야 한다.
class _DiaryOccurrence {
  const _DiaryOccurrence({required this.seedlingId, required this.entry});

  final int seedlingId;
  final DiaryEntry entry;
}

/// 재배자 마이 탭 "📅 나의 재배 활동 보기"에서 진입하는 월별 달력. 담당하는 모든 묘목의
/// 일지 작성일을 한 화면에 점으로 모아 보여준다 — 묘목별 일지 작성 화면
/// (`grower_diary_write_screen.dart`)은 새로 작성할 때만 쓰여서, 과거 작성 이력을 전체적으로
/// 돌아볼 방법이 없었다.
/// `Navigator.pushNamed`로 진입하는 독립 push 화면이라(탭 화면이 아님) `RevalidatableState`
/// 대신 일반 `State`를 쓴다.
class GrowerActivityCalendarScreen extends StatefulWidget {
  const GrowerActivityCalendarScreen({super.key});

  @override
  State<GrowerActivityCalendarScreen> createState() =>
      _GrowerActivityCalendarScreenState();
}

class _GrowerActivityCalendarScreenState
    extends State<GrowerActivityCalendarScreen> {
  final _growerRepository = GrowerRepository();
  final _diaryRepository = DiaryRepository();

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

  bool _loading = true;
  String? _errorMessage;
  int _seedlingCount = 0;

  /// 키는 [_dateOnly]로 시분초를 뗀 날짜 — 이 맵의 key 집합 자체가 "일지가 있는
  /// 날짜들의 집합" 역할을 겸해서, 점 표시 여부(`containsKey`)와 선택된 날짜의 요약
  /// 목록 조회를 같은 구조 하나로 처리한다.
  Map<DateTime, List<_DiaryOccurrence>> _diariesByDate = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _growerRepository.fetchSeedlings();
      if (seedlings.isEmpty) {
        setState(() {
          _seedlingCount = 0;
          _diariesByDate = {};
        });
        return;
      }
      final diaryLists = await Future.wait(
        seedlings.map((s) => _diaryRepository.fetchDiaries(s.id)),
      );
      final map = <DateTime, List<_DiaryOccurrence>>{};
      for (var i = 0; i < seedlings.length; i++) {
        final seedlingId = seedlings[i].id;
        for (final entry in diaryLists[i]) {
          // created_at은 UTC라 그대로 자르면 자정 근처 일지가 실제와 다른 날짜에
          // 찍힐 수 있어, 날짜를 그룹핑 키로 쓰는 이 화면에서는 로컬 시각으로
          // 변환한 뒤 자른다.
          final date = _dateOnly(entry.createdAt.toLocal());
          map
              .putIfAbsent(date, () => [])
              .add(_DiaryOccurrence(seedlingId: seedlingId, entry: entry));
        }
      }
      setState(() {
        _seedlingCount = seedlings.length;
        _diariesByDate = map;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }
    if (_seedlingCount == 0) {
      return const _EmptyState();
    }

    final occurrences = _selectedDate == null
        ? null
        : _diariesByDate[_selectedDate];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        children: [
          _MonthHeader(
            month: _currentMonth,
            onPrevious: _goToPreviousMonth,
            onNext: _goToNextMonth,
          ),
          const SizedBox(height: 16),
          _CalendarCard(
            month: _currentMonth,
            markedDates: _diariesByDate.keys.toSet(),
            selectedDate: _selectedDate,
            onSelectDate: (date) => setState(() => _selectedDate = date),
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 20),
            _SelectedDateSummary(
              date: _selectedDate!,
              occurrences: occurrences ?? const [],
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: onPrevious,
        ),
        Text('${month.year}년 ${month.month}월', style: AppTextStyles.title()),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.markedDates,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final DateTime month;
  final Set<DateTime> markedDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    // DateTime.weekday는 월=1..일=7이라 %7을 하면 일요일이 0이 되어, 일요일부터
    // 시작하는 요일 헤더와 맞는 앞쪽 빈 칸 수가 나온다.
    final leadingBlanks = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(label, style: AppTextStyles.caption()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final date = DateTime(month.year, month.month, day);
              return _DayCell(
                day: day,
                hasDiary: markedDates.contains(date),
                isSelected: selectedDate != null && selectedDate == date,
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasDiary,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final bool hasDiary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pink100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day', style: AppTextStyles.body(fontSize: 13)),
            const SizedBox(height: 3),
            if (hasDiary)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.pink500,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDateSummary extends StatelessWidget {
  const _SelectedDateSummary({required this.date, required this.occurrences});

  final DateTime date;
  final List<_DiaryOccurrence> occurrences;

  String get _dateLabel => '${date.month}월 ${date.day}일';

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(_dateLabel, style: AppTextStyles.title(fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              '이 날은 작성한 일지가 없어요',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_dateLabel, style: AppTextStyles.title(fontSize: 15)),
        const SizedBox(height: 10),
        for (final occurrence in occurrences) ...[
          _DiarySummaryCard(occurrence: occurrence),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DiarySummaryCard extends StatelessWidget {
  const _DiarySummaryCard({required this.occurrence});

  final _DiaryOccurrence occurrence;

  String get _preview {
    final content = occurrence.entry.content;
    return content.length > 40 ? '${content.substring(0, 40)}...' : content;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '묘목 #${occurrence.seedlingId}',
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(_preview, style: AppTextStyles.body(fontSize: 14)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              '아직 담당하는 묘목이 없어요',
              style: AppTextStyles.body(
                fontSize: 15,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '묘목이 배정되면 활동 캘린더가 채워져요',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: PigFigButton.outline(label: '다시 시도', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
