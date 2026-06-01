import '../../services/presence_client.dart';

/// Reachability tiers rendered as the green tick. NOT identity verification.
enum PresenceStatus { online, recent, stale, unknown }

/// Window after last_seen during which a non-online contact still counts as
/// "recent" (amber) rather than "stale" (grey).
const Duration recentWindow = Duration(hours: 24);

PresenceStatus presenceStatusFor(PresenceInfo? info, DateTime now) {
  if (info == null) return PresenceStatus.unknown;
  if (info.online) return PresenceStatus.online;
  final ls = info.lastSeen;
  if (ls == null) return PresenceStatus.stale;
  return now.toUtc().difference(ls.toUtc()) <= recentWindow
      ? PresenceStatus.recent
      : PresenceStatus.stale;
}
