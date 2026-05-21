import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: fromMe
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
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
                      color:
                          fromMe ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hhmm(timestamp.toLocal()),
                    style: TextStyle(
                      fontSize: 10,
                      color: (fromMe
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant)
                          .withValues(alpha: 0.7),
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
