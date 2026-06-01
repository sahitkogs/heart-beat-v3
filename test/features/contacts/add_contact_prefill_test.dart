import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/features/contacts/add_contact_screen.dart';

void main() {
  const hex =
      '116d49edaaee117f9f048fc1803b272412e3103dbd1f98971d5a77cb24e8c19b';

  testWidgets(
      'opens at paste stage prefilled when initialHex/initialName given',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddContactScreen(initialHex: hex, initialName: 'alice'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar title confirms we are on the pasteHex stage, not chooseMethod.
    expect(find.text('Paste hex code'), findsOneWidget);

    // 'Save contact' button is visible (it is the FilledButton on paste stage).
    expect(find.text('Save contact'), findsOneWidget);

    // Nickname field is prefilled — find the TextField whose controller has 'alice'.
    expect(find.widgetWithText(TextField, 'alice'), findsOneWidget);

    // Pubkey field contains the hex — look for the leading 8 chars that are
    // visible regardless of wrapping.
    expect(find.widgetWithText(TextField, hex), findsOneWidget);
  });
}
