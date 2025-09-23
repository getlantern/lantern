import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

class ProviderCarousel extends HookConsumerWidget {
  final List<Widget> cards;
  final double? height;
  final EdgeInsets itemPadding;
  final double viewportFraction;
  final ValueChanged<int>? onPageChanged;

  const ProviderCarousel({
    super.key,
    required this.cards,
    this.height,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 4),
    this.viewportFraction = 1.0,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final current = useState(0);

    // final w = MediaQuery.sizeOf(context).width;
    final isDesktop = PlatformUtils.isDesktop;
    
    final controller = useMemoized(
        () => PageController(viewportFraction: .98, keepPage: true));
    useEffect(() => controller.dispose, [controller]);

    void goTo(int page) {
      if (page < 0 || page >= cards.length) return;
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }

    final defaultHeight = isDesktop ? 340.0 : 345.0;
    final resolvedHeight = height ?? defaultHeight;
    final showControls = cards.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: resolvedHeight,
          child: PageView.builder(
            controller: controller,
            itemCount: cards.length,
            padEnds: false,
            physics: const PageScrollPhysics(),
            onPageChanged: (i) {
              current.value = i;
              onPageChanged?.call(i);
            },
            itemBuilder: (context, idx) => Padding(
              padding: itemPadding,
              child: cards[idx],
            ),
          ),
        ),
        // Dots
        if (showControls) ...[
          const SizedBox(height: defaultSize),
          _CarouselControls(
            count: cards.length,
            current: current.value,
            onDotTap: (i) => goTo(i),
            onPrev: current.value > 0 ? () => goTo(current.value - 1) : null,
            onNext: current.value < cards.length - 1
                ? () => goTo(current.value + 1)
                : null,
            leftAsset: AppImagePaths.arrowBack,
            rightAsset: AppImagePaths.arrowForward,
          ),
        ],
      ],
    );
  }
}

class _CarouselControls extends StatelessWidget {
  final int count;
  final int current;
  final ValueChanged<int> onDotTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  final String? leftAsset;
  final String? rightAsset;

  const _CarouselControls({
    required this.count,
    required this.current,
    required this.onDotTap,
    required this.onPrev,
    required this.onNext,
    this.leftAsset,
    this.rightAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          enabled: onPrev != null,
          onTap: onPrev,
          assetPath: leftAsset,
          semanticLabel: 'previous'.i18n,
        ),
        const SizedBox(width: 112),
        _CarouselDots(
          count: count,
          current: current,
          onTap: onDotTap,
        ),
        const SizedBox(width: 112),
        _ArrowButton(
          enabled: onNext != null,
          onTap: onNext,
          assetPath: rightAsset,
          right: true,
          semanticLabel: 'next'.i18n,
        ),
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  final int count;
  final int current;
  final ValueChanged<int> onTap;

  const _CarouselDots({
    required this.count,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: List.generate(count, (i) {
        final active = i == current;
        final fill = active ? AppColors.gray4 : AppColors.gray2;
        return Semantics(
          selected: active,
          label: 'Page ${i + 1} of $count',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () => onTap(i),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.gray3, width: 1),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;
  final String? assetPath;
  final bool right;
  final String semanticLabel;

  const _ArrowButton({
    required this.enabled,
    required this.onTap,
    required this.semanticLabel,
    this.assetPath,
    this.right = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? AppColors.black1 : AppColors.gray4;

    Widget icon = assetPath != null
        ? AppImage(path: assetPath!, width: 24, height: 24, color: iconColor)
        : Icon(
            right ? Icons.chevron_right : Icons.chevron_left,
            size: 24,
            color: iconColor,
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(child: icon),
        ),
      ),
    );
  }
}
