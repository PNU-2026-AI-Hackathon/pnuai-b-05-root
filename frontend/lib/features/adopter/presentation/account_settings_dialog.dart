import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/notification_preference_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../auth/data/accounts_repository.dart';

/// 마이페이지 톱니바퀴 → "전체 설정" 모달. 닉네임 수정(서버 저장)과 알림 종류
/// on/off(로컬 저장)를 한 화면에서 처리한다.
///
/// 성공 시 새 닉네임(`String`)을 반환해 호출부가 재조회 없이 화면을 바로
/// 갱신할 수 있게 한다. 취소/실패로 닫히면 `null`.
Future<String?> showAccountSettingsDialog(
  BuildContext context, {
  required String initialNickname,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => AccountSettingsDialog(initialNickname: initialNickname),
  );
}

class AccountSettingsDialog extends StatefulWidget {
  const AccountSettingsDialog({super.key, required this.initialNickname});

  final String initialNickname;

  @override
  State<AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<AccountSettingsDialog> {
  final _accountsRepository = AccountsRepository();
  final _nicknameController = TextEditingController();

  bool _loadingPreferences = true;
  bool _saving = false;
  String? _errorMessage;

  final Map<NotificationPreferenceType, bool> _preferences = {
    for (final type in NotificationPreferenceType.values) type: true,
  };

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.initialNickname;
    _loadPreferences();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final userId = await TokenStorage().readUserId();
    if (userId == null) {
      if (mounted) setState(() => _loadingPreferences = false);
      return;
    }
    final storage = NotificationPreferenceStorage(userId: userId);
    final loaded = <NotificationPreferenceType, bool>{};
    for (final type in NotificationPreferenceType.values) {
      loaded[type] = await storage.isEnabled(type);
    }
    if (!mounted) return;
    setState(() {
      _preferences.addAll(loaded);
      _loadingPreferences = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final nickname = _nicknameController.text.trim();
      await _accountsRepository.updateNickname(nickname);
      await TokenStorage().saveNickname(nickname);

      final userId = await TokenStorage().readUserId();
      if (userId != null) {
        final storage = NotificationPreferenceStorage(userId: userId);
        for (final entry in _preferences.entries) {
          await storage.setEnabled(entry.key, entry.value);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(nickname);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '전체 설정',
                      style: AppTextStyles.title(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '닉네임',
                style: AppTextStyles.body(
                  fontSize: 13,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(hintText: '닉네임을 입력해주세요'),
              ),
              const SizedBox(height: 20),
              Text(
                '알림 설정',
                style: AppTextStyles.body(
                  fontSize: 13,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (_loadingPreferences)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.pink500),
                  ),
                )
              else ...[
                _PreferenceToggle(
                  title: '묘목 상태 및 이상 알림',
                  subtitle: '물주기, 조명 이상 발생 시 알림',
                  value: _preferences[NotificationPreferenceType.seedlingAlert]!,
                  onChanged: (value) => setState(
                    () => _preferences[NotificationPreferenceType.seedlingAlert] =
                        value,
                  ),
                ),
                _PreferenceToggle(
                  title: '오늘의 성장 일지 알림',
                  subtitle: '재배자가 일지를 올리면 알림',
                  value: _preferences[NotificationPreferenceType.growthDiary]!,
                  onChanged: (value) => setState(
                    () => _preferences[NotificationPreferenceType.growthDiary] =
                        value,
                  ),
                ),
                _PreferenceToggle(
                  title: '수확 & 배송 일정 알림',
                  subtitle: '무화과 수확 시기 안내',
                  value:
                      _preferences[NotificationPreferenceType.harvestDelivery]!,
                  onChanged: (value) => setState(
                    () =>
                        _preferences[NotificationPreferenceType.harvestDelivery] =
                            value,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.errorRed,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PigFigButton.positive(
                label: '저장 완료',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceToggle extends StatelessWidget {
  const _PreferenceToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body(
                    fontSize: 14,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.green500,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
