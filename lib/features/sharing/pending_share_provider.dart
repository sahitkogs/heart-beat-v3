import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text the user shared INTO heart•beat (ACTION_SEND), awaiting forward to a
/// chosen chat. Null when not forwarding. Set by the receive-share handler,
/// cleared when a chat is picked or the user cancels.
final pendingShareTextProvider = StateProvider<String?>((_) => null);
