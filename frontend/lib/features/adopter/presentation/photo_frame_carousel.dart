import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/step_indicator.dart';

/// 사진에 씌우는 장식 프레임 4종 — 캐러셀 페이지 순서와 동일(index 0 = 기본).
enum PhotoFrameStyle {
  none('기본'),
  craftPaper('크래프트 종이 프레임'),
  wood('나무 액자 프레임'),
  figLeaf('무화과잎 코너 장식');

  const PhotoFrameStyle(this.label);
  final String label;
}

const _kraftPaper = Color(0xFFDDC49A);
const _kraftPaperDark = Color(0xFFC7A876);
const _woodDark = Color(0xFF6E4A2E);
const _woodLight = Color(0xFFB98354);

/// 일지 상세 화면의 사진(내용은 고정)을 감싸는 프레임을 좌우로 스와이프해서
/// 고르는 캐러셀 — 가운데 항목은 크게, 양옆 항목은 작고 화면 밖으로 살짝
/// 잘려 보인다(LOGZINE "Today's stand" 참고). 선택값은 영속화하지 않는다
/// (화면을 벗어나면 항상 기본 프레임부터 다시 시작).
class PhotoFrameCarousel extends StatefulWidget {
  const PhotoFrameCarousel({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  State<PhotoFrameCarousel> createState() => _PhotoFrameCarouselState();
}

class _PhotoFrameCarouselState extends State<PhotoFrameCarousel> {
  static const _viewportFraction = 0.8;
  late final PageController _controller = PageController(
    viewportFraction: _viewportFraction,
  );
  int _frameIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carouselHeight = MediaQuery.of(context).size.height * 0.40;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: carouselHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: PhotoFrameStyle.values.length,
            onPageChanged: (i) => setState(() => _frameIndex = i),
            itemBuilder: (context, index) => _buildPage(index),
          ),
        ),
        const SizedBox(height: 14),
        DotProgressIndicator(
          current: _frameIndex,
          total: PhotoFrameStyle.values.length,
        ),
        const SizedBox(height: 8),
        Text(
          PhotoFrameStyle.values[_frameIndex].label,
          style: AppTextStyles.caption(
            fontSize: 13,
            color: AppColors.textMuted,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildPage(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final page = _controller.hasClients
            ? (_controller.page ?? _frameIndex.toDouble())
            : _frameIndex.toDouble();
        final distance = (page - index).abs().clamp(0.0, 1.0);
        final scale = 1.0 - distance * 0.22;
        final opacity = (1.0 - distance * 0.5).clamp(0.5, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _FramedPhoto(
          style: PhotoFrameStyle.values[index],
          imageUrl: widget.imageUrl,
        ),
      ),
    );
  }
}

class _FramedPhoto extends StatelessWidget {
  const _FramedPhoto({required this.style, required this.imageUrl});

  final PhotoFrameStyle style;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
          size: 40,
        ),
      ),
    );
    return switch (style) {
      PhotoFrameStyle.none => Center(child: image),
      PhotoFrameStyle.craftPaper => _CraftPaperFrame(image: image),
      PhotoFrameStyle.wood => _WoodFrame(image: image),
      PhotoFrameStyle.figLeaf => _FigLeafFrame(image: image),
    };
  }
}

/// 크래프트 종이 프레임 — 두꺼운 크래프트지 매트 + 얇은 흰색 인화지 마운트.
class _CraftPaperFrame extends StatelessWidget {
  const _CraftPaperFrame({required this.image});

  final Widget image;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kraftPaper,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kraftPaperDark, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(4),
        child: ClipRect(child: image),
      ),
    );
  }
}

/// 나무 액자 프레임 — 어두운 나무색 외곽 + 베벨 하이라이트 + 안쪽 그림자 립
/// 3겹을 중첩해 평평한 색상만으로 액자의 입체감을 흉내낸다.
class _WoodFrame extends StatelessWidget {
  const _WoodFrame({required this.image});

  final Widget image;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _woodDark,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Container(
        color: _woodLight,
        padding: const EdgeInsets.all(4),
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(2),
          child: ClipRect(child: image),
        ),
      ),
    );
  }
}

/// 무화과잎 코너 장식 — 두꺼운 테두리 대신 사진 네 귀퉁이에 잎 모양(원 2개
/// 겹침, fig_tree_illustration.dart의 leaf=원형 Container 기법을 로컬로
/// 재구현)과 얇은 초록 테두리만 둘러 은은하게 장식한다.
class _FigLeafFrame extends StatelessWidget {
  const _FigLeafFrame({required this.image});

  final Widget image;

  static const _leafGreen = AppColors.green800;
  static const _leafGreenLight = Color(0xFF6FA85C);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final leafSize = (w * 0.16).clamp(18.0, 34.0);
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: w * 0.06,
                  vertical: h * 0.06,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _leafGreen, width: 1.5),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipRect(child: image),
              ),
            ),
            Positioned(top: 0, left: 0, child: _cornerLeaves(leafSize)),
            Positioned(top: 0, right: 0, child: _cornerLeaves(leafSize)),
            Positioned(bottom: 0, right: 0, child: _cornerLeaves(leafSize)),
            Positioned(bottom: 0, left: 0, child: _cornerLeaves(leafSize)),
          ],
        );
      },
    );
  }

  Widget _cornerLeaves(double size) {
    return SizedBox(
      width: size * 1.3,
      height: size * 1.3,
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: _leaf(size, _leafGreen)),
          Positioned(
            top: size * 0.34,
            left: size * 0.34,
            child: _leaf(size * 0.68, _leafGreenLight),
          ),
        ],
      ),
    );
  }

  Widget _leaf(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
