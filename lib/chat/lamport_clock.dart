/// In-memory monotonic counter for a single chat. The persistent counterpart
/// lives in the `LamportSeq` drift table (see `ChatsDao`); this class is the
/// working copy used during a single send/receive episode.
class LamportClock {
  int _value = 0;

  /// Current counter value (does not increment).
  int get value => _value;

  /// Increment and return the new value.
  int tick() => ++_value;

  /// Advance to [remote] if it is strictly higher; otherwise no-op.
  void observe(int remote) {
    if (remote > _value) _value = remote;
  }
}
