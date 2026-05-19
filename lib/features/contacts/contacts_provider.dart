import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/contacts_repository.dart';
import '../../data/models/contact.dart';

final contactsRepositoryProvider = FutureProvider<ContactsRepository>(
  (_) => ContactsRepository.create(),
);

/// Re-fetches whenever invalidated.
final contactsListProvider = FutureProvider<List<Contact>>((ref) async {
  final repo = await ref.watch(contactsRepositoryProvider.future);
  return repo.loadAll();
});
