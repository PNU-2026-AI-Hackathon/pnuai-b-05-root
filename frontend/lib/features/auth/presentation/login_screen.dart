import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/fcm_token_repository.dart';
import '../../../core/storage/notification_priming_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/notification_priming_dialog.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/pigfig_logo.dart';
import '../../../shared/widgets/role_toggle.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _tokenStorage = TokenStorage();
  final _fcmService = FcmService();
  final _fcmTokenRepository = FcmTokenRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.adopter;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (await _needsNotificationPriming(result.userId)) {
        // 프라이밍 다이얼로그를 처음 보여주는 순간만 응답을 기다린다 — 사용자의 명시적
        // 선택이 필요한 흐름이라 여기서만큼은 로그인 흐름을 잠깐 막는 게 자연스럽다.
        await _primeThenMaybeRegister(result.userId);
      } else {
        // 이미 이 계정으로 한 번 판단이 끝났다면 기존과 동일하게 로그인 흐름을 막지 않는다.
        unawaited(_registerPushToken());
      }
      if (!mounted) return;
      if (result.role == UserRole.adopter) {
        // 이전에 본 적 있는지 따지지 않고 입양자 로그인에 성공할 때마다 매번 보여준다.
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else {
        Navigator.of(context).pushReplacementNamed('/grower');
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 이 계정에 알림 권한 프라이밍 다이얼로그를 아직 안 보여준 Android인지 확인한다.
  /// 다른 플랫폼(web/windows 등)은 [FcmService]가 애초에 아무것도 하지 않으므로
  /// 다이얼로그 자체를 띄울 필요가 없다.
  Future<bool> _needsNotificationPriming(String userId) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return !await NotificationPrimingStorage(userId: userId).hasSeenPriming();
  }

  /// 프라이밍 다이얼로그를 보여주고, "허용"을 선택했을 때만 실제 OS 권한 요청(토큰 등록)까지
  /// 이어간다. 응답과 무관하게 다시 묻지 않도록 먼저 "본 적 있음"으로 기록한다.
  Future<void> _primeThenMaybeRegister(String userId) async {
    await NotificationPrimingStorage(userId: userId).markSeen();
    if (!mounted) return;
    final accepted = await showNotificationPrimingDialog(context);
    if (accepted == true) {
      await _registerPushToken();
    }
    // '나중에'(또는 바깥 탭)면 getDeviceToken()을 아예 호출하지 않으므로
    // OS 권한 요청 자체가 트리거되지 않는다.
  }

  /// 로그인 성공 직후 FCM 기기 토큰을 발급받아 백엔드에 등록한다.
  /// 권한 거부, 미지원 플랫폼, 네트워크 오류 등으로 실패해도 로그인 흐름에는
  /// 영향을 주지 않는 부가 기능이라 넓게 catch한다.
  Future<void> _registerPushToken() async {
    try {
      final deviceToken = await _fcmService.getDeviceToken();
      if (deviceToken == null) return;
      final accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null) return;
      await _fcmTokenRepository.registerToken(
        token: deviceToken,
        accessToken: accessToken,
      );
    } catch (_) {
      // 푸시 알림은 부가 기능 — 실패해도 로그인 흐름에 영향 없음
    }
  }

  void _goToRegister() {
    Navigator.of(context).pushNamed('/register', arguments: _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 84),
              const Hero(
                tag: 'pigfig-logo',
                child: PigFigLogo(size: 74, variant: PigFigLogoVariant.symbol),
              ),
              const SizedBox(height: 12),
              Text('Pig.Fig.', style: AppTextStyles.display(fontSize: 34)),
              const SizedBox(height: 4),
              Text(
                '나의 무화과를 만나러 가요 🌱',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              RoleToggle(
                selected: _selectedRole,
                onChanged: (role) => setState(() => _selectedRole = role),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: '이메일'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.errorRed,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PigFigButton.primary(
                label: '로그인',
                onPressed: _submit,
                loading: _loading,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '비밀번호 찾기',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '|',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.dotInactive,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _goToRegister,
                    child: Text(
                      '회원가입',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.badgeGreenText,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
