import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/role_toggle.dart';
import '../data/auth_repository.dart';

/// 로그인 화면 "회원가입" 링크로 진입. 선택된 [UserRole]을 route argument로 받아
/// 기본 선택값으로 사용한다.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  UserRole? _selectedRole;
  bool _loading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedRole ??=
        ModalRoute.of(context)?.settings.arguments as UserRole? ??
        UserRole.adopter;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() => _errorMessage = '비밀번호가 일치하지 않아요.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _authRepository.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole!,
        nickname: _nicknameController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입 성공! 로그인해주세요 🌱')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text('회원가입', style: AppTextStyles.title(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('어떤 역할로 가입할까요?', style: AppTextStyles.guide(fontSize: 15)),
              const SizedBox(height: 12),
              RoleToggle(
                selected: _selectedRole ?? UserRole.adopter,
                onChanged: (role) => setState(() => _selectedRole = role),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(hintText: '닉네임'),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextField(
                controller: _passwordConfirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호 확인'),
              ),
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
              const SizedBox(height: 22),
              PigFigButton.primary(
                label: '회원가입',
                onPressed: _submit,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
