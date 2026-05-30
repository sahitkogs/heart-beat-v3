import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/features/chat/message_bubble.dart';

void main() {
  // 10.4.3d UI — receipt status moved from icon to inline text label
  // shown to the right of the timestamp.

  testWidgets('outbound bubble shows "sent" text for sent state',
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
    expect(find.text('sent'), findsOneWidget);
    expect(find.text('delivered'), findsNothing);
    expect(find.text('read'), findsNothing);
  });

  testWidgets('outbound bubble shows "delivered" for delivered state',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.delivered,
        ),
      ),
    ));
    expect(find.text('delivered'), findsOneWidget);
  });

  testWidgets('outbound bubble shows "read" for read state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.read,
        ),
      ),
    ));
    expect(find.text('read'), findsOneWidget);
  });

  testWidgets('outbound failed bubble shows retry hint + tap fires callback',
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
    final label = find.text('failed — tap to retry');
    expect(label, findsOneWidget);
    await tester.tap(label);
    expect(taps, 1);
  });

  testWidgets('inbound bubble never renders a status label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: false,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.read, // ignored when fromMe == false
        ),
      ),
    ));
    expect(find.text('sent'), findsNothing);
    expect(find.text('delivered'), findsNothing);
    expect(find.text('read'), findsNothing);
    expect(find.text('failed — tap to retry'), findsNothing);
  });
}
