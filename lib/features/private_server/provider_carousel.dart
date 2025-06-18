import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

class ProviderCarousel extends HookConsumerWidget {
  final List<Widget> cards;

  const ProviderCarousel({super.key, required this.cards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = useState(0);
    final controller = usePageController(viewportFraction: .95);
    void goTo(int page) {
      if (page < 0 || page >= cards.length) return;
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 350.h,
          child: PageView.builder(
            controller: controller,
            itemCount: cards.length,
            onPageChanged: (idx) => current.value = idx,
            itemBuilder: (context, idx) => cards[idx],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios),
              onPressed:
                  current.value > 0 ? () => goTo(current.value - 1) : null,
              color: current.value > 0 ? Colors.black : Colors.grey[400],
              tooltip: 'previous'.i18n,
              iconSize: 24,
              padding: EdgeInsets.zero,
              splashRadius: 20,
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cards.length, (idx) {
                final isActive = idx == current.value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.gray4 : AppColors.gray2,
                    border: Border.all(color: AppColors.gray3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              path: AppImagePaths.arrowForward,
              onPressed: current.value < cards.length - 1
                  ? () => goTo(current.value + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
