import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_v3/chat/chat_providers.dart';
import 'package:app_v3/chat/message_service.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/features/chat/chat_list_screen.dart';
import 'package:app_v3/features/chat/message_service_provider.dart';
import 'package:app_v3/features/notifications/fcm_provider.dart';
import 'package:app_v3/features/sharing/pending_share_provider.dart';

/// Overrides that let [ChatListScreen] build under flutter_test without
/// touching platform channels (FCM, MessageService) or a real database.
/// The chats stream is overridden to an empty list so [_buildList] returns
/// the empty-state placeholder without reading the DB / contacts; the
/// forward banner lives ABOVE the list and is unaffected by chat content.
List<Override> _baseOverrides() => [
      chatsStreamProvider.overrideWith((ref) => Stream.value(<Chat>[])),
      // Keep these init futures pending forever so initState's fire-and-forget
      // reads never resolve into real platform work.
      fcmRegistrationProvider.overrideWith((ref) => Completer<void>().future),
      messageServiceProvider
          .overrideWith((ref) => Completer<MessageService>().future),
    ];

Widget _harness(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatListScreen()),
    );

void main() {
  testWidgets('forward banner shows when pendingShareText is set', (t) async {
    final container = ProviderContainer(overrides: _baseOverrides());
    addTearDown(container.dispose);
    container.read(pendingShareTextProvider.notifier).state =
        'Add bob: https://example.com';

    await t.pumpWidget(_harness(container));
    await t.pump();

    expect(find.textContaining('Select a chat to forward'), findsOneWidget);
  });

  testWidgets('no forward banner when pendingShareText is null', (t) async {
    final container = ProviderContainer(overrides: _baseOverrides());
    addTearDown(container.dispose);

    await t.pumpWidget(_harness(container));
    await t.pump();

    expect(find.textContaining('Select a chat to forward'), findsNothing);
  });
}
