import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

enum SubscriptionTagType {
  expired,
  pro,
}

class SubscriptionTags extends StatelessWidget {
  final SubscriptionTagType type;

  const SubscriptionTags({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isExpired = type == SubscriptionTagType.expired;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
          color: isExpired ? context.statusErrorBg : context.statusSuccessBg,
          border: Border.all(
            color: isExpired ? context.statusErrorBorder : context.statusSuccessBorder,
          ),
          borderRadius: BorderRadius.circular(8)),
      child: Text(
        isExpired ? 'subscription_expired'.i18n : 'pro'.i18n,
        style: textTheme.labelMedium!.copyWith(
          color: isExpired ? context.statusErrorText : context.statusSuccessText,
        ),
      ),
    );
  }
}
