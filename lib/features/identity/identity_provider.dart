import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/identity_service.dart';
import '../../services/key_storage.dart';
import '../../services/signing_service.dart';

final keyStorageProvider = Provider<KeyStorage>((_) => KeyStorage());

final identityServiceProvider = Provider<IdentityService>(
  (ref) => IdentityService(ref.watch(keyStorageProvider)),
);

final signingServiceProvider = Provider<SigningService>(
  (ref) => SigningService(ref.watch(keyStorageProvider)),
);

final identityProvider = FutureProvider<Identity>(
  (ref) => ref.watch(identityServiceProvider).loadOrCreate(),
);
