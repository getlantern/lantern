import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class ProviderCarousel extends StatefulWidget {
  final List<Widget> cards;

  const ProviderCarousel({super.key, required this.cards});

  @override
  State<ProviderCarousel> createState() => _ProviderCarouselState();
}

class _ProviderCarouselState extends State<ProviderCarousel> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  void _goTo(int page) {
    if (page < 0 || page >= widget.cards.length) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (idx) => setState(() => _current = idx),
            itemBuilder: (context, idx) => widget.cards[idx],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios),
              onPressed: _current > 0 ? () => _goTo(_current - 1) : null,
              color: _current > 0 ? Colors.black : Colors.grey[400],
              tooltip: 'previous'.i18n,
              iconSize: 24,
              padding: EdgeInsets.zero,
              splashRadius: 20,
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.cards.length, (idx) {
                final isActive = idx == _current;
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
            IconButton(
              icon: Icon(Icons.arrow_forward_ios),
              onPressed: _current < widget.cards.length - 1
                  ? () => _goTo(_current + 1)
                  : null,
              color: _current < widget.cards.length - 1
                  ? Colors.black
                  : Colors.grey[400],
              tooltip: 'next'.i18n,
              iconSize: 24,
              padding: EdgeInsets.zero,
              splashRadius: 20,
            ),
          ],
        ),
      ],
    );
  }
}
