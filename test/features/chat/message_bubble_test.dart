import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/features/chat/message_bubble.dart';

void main() {
  testWidgets('outbound bubble renders single check for sent state',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.sent,
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('outbound read bubble renders double check', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.read,
        ),
      ),
    ));
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('outbound failed bubble shows error + tap calls callback',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.failed,
          onRetryTap: () => taps++,
        ),
      ),
    ));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.error_outline));
    expect(taps, 1);
  });

  testWidgets('inbound bubble never renders a tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: false,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.read, // ignored when fromMe == false
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
