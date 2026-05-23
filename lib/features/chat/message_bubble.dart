import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.body,
    required this.fromMe,
    required this.timestamp,
    this.senderLabel,
  });

  final String body;
  final bool fromMe;
  final DateTime timestamp;

  /// When non-null and [fromMe] is false, renders a small gray label line
  /// above the bubble showing the truncated sender pubkey.
  final String? senderLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = fromMe
        ? AppColors.accent
        : (isDark ? AppColors.surfaceDark : AppColors.paperShade);
    final bubbleFg = fromMe
        ? AppColors.paper
        : (isDark ? AppColors.inkOnDark : AppColors.ink);
    final mutedFg = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hhmm(timestamp.toLocal()),
                    style: TextStyle(
                      fontSize: 10,
                      color: bubbleFg.withValues(alpha: 0.7),
                    ),
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
