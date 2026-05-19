import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/identity_service.dart';
import '../../services/key_storage.dart';

final keyStorageProvider = Provider<KeyStorage>((_) => KeyStorage());

final identityServiceProvider = Provider<IdentityService>(
  (ref) => IdentityService(ref.watch(keyStorageProvider)),
);

/// Resolves once at app start: loads or generates the user's Identity.
final identityProvider = FutureProvider<Identity>(
  (ref) => ref.watch(identityServiceProvider).loadOrCreate(),
);
