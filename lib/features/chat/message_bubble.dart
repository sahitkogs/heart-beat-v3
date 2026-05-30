import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.body,
    required this.fromMe,
    required this.timestamp,
    this.senderLabel,
    this.deliveryState,
    this.onRetryTap,
  });

  final String body;
  final bool fromMe;
  final DateTime timestamp;

  /// When non-null and [fromMe] is false, renders a small gray label line
  /// above the bubble showing the truncated sender pubkey.
  final String? senderLabel;

  /// Per-message delivery progress. Only rendered for outbound bubbles
  /// (`fromMe == true`); inbound bubbles ignore it.
  final DeliveryState? deliveryState;

  /// Tap callback for the failed tick. Wired only when [deliveryState] is
  /// [DeliveryState.failed]; ignored otherwise.
  final VoidCallback? onRetryTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = fromMe
        ? AppColors.accent
        : (isDark ? AppColors.surfaceDark : AppColors.paperShade);
    // 10.4.3d UI — pure white on the rust outbound bubble for ~6:1 contrast
    // (the prior `paper` cream tone shared the bubble's warm hue and read
    // as muddy, especially at the larger body size).
    final bubbleFg = fromMe
        ? Colors.white
        : (isDark ? AppColors.inkOnDark : AppColors.ink);
    final mutedFg = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    // Footer color (timestamp + status label) — semi-transparent over the
    // bubble fg so it sits visibly but doesn't fight the body text.
    final footerFg = bubbleFg.withValues(alpha: 0.75);
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment:
              fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderLabel != null && !fromMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 2),
                child: Text(
                  senderLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedFg,
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment:
                    fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: 'serif',
                      color: bubbleFg,
                      // 10.4.3d UI — body bumped from 14 (default) → 18,
                      // matching the WhatsApp comfort point. Timestamp +
                      // status label stay small so the bubble doesn't
                      // become bottom-heavy.
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hhmm(timestamp.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: footerFg,
                        ),
                      ),
                      if (fromMe && deliveryState != null) ...[
                        const SizedBox(width: 6),
                        _StatusLabel(
                          state: deliveryState!,
                          color: footerFg,
                          onRetryTap: onRetryTap,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hhmm(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.state,
    required this.color,
    this.onRetryTap,
  });
  final DeliveryState state;
  final Color color;
  final VoidCallback? onRetryTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      DeliveryState.sent => 'sent',
      DeliveryState.delivered => 'delivered',
      DeliveryState.read => 'read',
      DeliveryState.failed => 'failed — tap to retry',
    };
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: state == DeliveryState.failed
            ? Theme.of(context).colorScheme.error
            : color,
        fontStyle: FontStyle.italic,
      ),
    );
    if (state == DeliveryState.failed) {
      return GestureDetector(onTap: onRetryTap, child: text);
    }
    return text;
  }
}
