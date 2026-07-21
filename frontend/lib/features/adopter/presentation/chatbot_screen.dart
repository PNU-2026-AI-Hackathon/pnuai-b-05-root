import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pig_character.dart';
import '../data/chatbot_repository.dart';

enum _Sender { bot, user }

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});

  final _Sender sender;
  final String text;
}

/// 1l — AI 챗봇: 무화과 Q&A. `POST /api/chatbot/ask/`와 실제 연동한다.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const _suggestedQuestions = ['물은 얼마나 자주 줘요?', '수확은 언제쯤?', '가지치기 방법'];

  final _repository = ChatbotRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(sender: _Sender.bot, text: '꿀꿀! 무화과에 대해 뭐든 물어보세요 🌱'),
  ];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.user, text: trimmed));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final answer = await _repository.ask(trimmed);
      setState(
        () => _messages.add(_ChatMessage(sender: _Sender.bot, text: answer)),
      );
    } on ApiException catch (e) {
      setState(
        () => _messages.add(_ChatMessage(sender: _Sender.bot, text: e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7E4D8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '오늘',
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: const Color(0xFF9B9686),
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  for (final message in _messages) ...[
                    const SizedBox(height: 12),
                    if (message.sender == _Sender.bot)
                      _BotBubble(text: message.text)
                    else
                      _UserBubble(text: message.text),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const _BotTypingBubble(),
                  ],
                ],
              ),
            ),
            _SuggestedQuestions(
              questions: _suggestedQuestions,
              onTap: _loading ? null : _send,
            ),
            _ChatInputBar(
              controller: _controller,
              loading: _loading,
              onSend: () => _send(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.pink100,
                    shape: BoxShape.circle,
                  ),
                  child: const PigCharacter(width: 28),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.green500,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '무화과 박사 피그',
                style: AppTextStyles.body(
                  fontSize: 15,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'AI가 바로 답해드려요',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.badgeGreenText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.pink100,
            shape: BoxShape.circle,
          ),
          child: const Text('🐷', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: AppTextStyles.body(fontSize: 14).copyWith(height: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BotTypingBubble extends StatelessWidget {
  const _BotTypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.pink100,
            shape: BoxShape.circle,
          ),
          child: const Text('🐷', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.pink500,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.65,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
            color: AppColors.pink500,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(
            text,
            style: AppTextStyles.body(
              fontSize: 14,
              color: Colors.white,
            ).copyWith(height: 1.6),
          ),
        ),
      ),
    );
  }
}

class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.questions, required this.onTap});

  final List<String> questions;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final question in questions)
            GestureDetector(
              onTap: onTap == null ? null : () => onTap!(question),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFF0D3D9),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  question,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.badgePinkText,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F1E9),
                borderRadius: BorderRadius.circular(23),
              ),
              child: TextField(
                controller: controller,
                enabled: !loading,
                onSubmitted: (_) => onSend(),
                style: AppTextStyles.body(fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: '궁금한 걸 물어보세요...',
                  hintStyle: AppTextStyles.body(
                    fontSize: 14,
                    color: const Color(0xFFB7B2A4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.pink500.withValues(alpha: loading ? 0.5 : 1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
