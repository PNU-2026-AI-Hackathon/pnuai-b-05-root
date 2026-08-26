import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/diary_repository.dart';
import 'grower_diary_write_screen.dart';

/// `/grower/diary-list` route argument: 일지 탭에서 탭한 담당 묘목.
class GrowerDiaryListArgs {
  const GrowerDiaryListArgs({required this.seedlingId});

  final int seedlingId;
}

/// 묘목 한 그루의 일지 전체를 시간 역순으로 보여주는 리스트 화면. 일지 탭
/// (`GrowerDiaryTabScreen`)에서 묘목 카드를 탭하면 진입하며, "일지 쓰기" 버튼을 누르면
/// `GrowerDiaryWriteScreen`(`/grower/diary-write`)으로 이동한다. 탭 화면이 아니라 독립
/// push 화면이라(`grower_activity_calendar_screen.dart`와 동일한 이유로) `RevalidatableState`
/// 대신 일반 `State`를 쓴다.
class GrowerDiaryListScreen extends StatefulWidget {
  const GrowerDiaryListScreen({super.key});

  @override
  State<GrowerDiaryListScreen> createState() => _GrowerDiaryListScreenState();
}

class _GrowerDiaryListScreenState extends State<GrowerDiaryListScreen> {
  final _diaryRepository = DiaryRepository();

  bool _loading = true;
  String? _errorMessage;
  List<DiaryEntry> _entries = const [];

  bool _initialized = false;

  /// `ModalRoute.of(context)`는 위젯이 트리에 삽입된 뒤에만 조회할 수 있어
  /// `initState()`가 아니라 여기서 첫 조회를 시작한다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  int get _seedlingId =>
      (ModalRoute.of(context)!.settings.arguments as GrowerDiaryListArgs)
          .seedlingId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final entries = await _diaryRepository.fetchDiaries(_seedlingId);
      setState(() => _entries = entries);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWrite() async {
    await Navigator.of(context).pushNamed(
      '/grower/diary-write',
      arguments: GrowerDiaryWriteArgs(seedlingId: _seedlingId),
    );
    // 작성 화면에서 새 일지를 남겼을 수 있으니 돌아오면 다시 불러온다.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '무화과 #$_seedlingId 일지',
                style: AppTextStyles.title(
                  fontSize: 20,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '지금까지 남긴 성장 기록이에요',
                style: AppTextStyles.guide(
                  fontSize: 14,
                  color: AppColors.badgeGreenText,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),
              const SizedBox(height: 12),
              PigFigButton.primary(label: '일지 쓰기', onPressed: _openWrite),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return _MessageState(
        emoji: '😢',
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (_entries.isEmpty) {
      return const _MessageState(emoji: '📋', message: '아직 작성한 일지가 없어요');
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DiaryCard(entry: _entries[index]),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry});

  final DiaryEntry entry;

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(entry.createdAt),
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: const Color(0xFFB7B2A4),
                ),
              ),
              Row(
                children: [
                  if (entry.growthStageLabel != null)
                    StatusBadge(
                      label: entry.growthStageLabel!,
                      background: AppColors.green500,
                      pill: false,
                    ),
                  if (entry.yoloStatusTag != null) ...[
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: entry.yoloStatusTag!,
                      background: AppColors.badgeGreenBg,
                      textColor: AppColors.badgeGreenText,
                      pill: false,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.content,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textPrimary,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.emoji,
    required this.message,
    this.onRetry,
  });

  final String emoji;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}
