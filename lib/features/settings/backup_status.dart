/// The line under "Backup" in Settings.
String backupStatus({
  required bool signedIn,
  required bool running,
  required String? problem,
  required int? backedUpAt,
  required int waiting,
  required DateTime now,
}) {
  if (!signedIn) return 'Off. Sign in to keep a private copy of your spends online.';
  if (running && waiting > 0) return 'Backing up…';
  if (problem != null && waiting > 0) return 'Waiting for internet. $waiting ${waiting == 1 ? 'change' : 'changes'} to back up.';
  if (backedUpAt == null) return 'On. Your first backup starts soon.';
  final mins = now.difference(DateTime.fromMillisecondsSinceEpoch(backedUpAt)).inMinutes;
  final when = mins < 1
      ? 'just now'
      : mins < 60
          ? '$mins min ago'
          : mins < 60 * 24
              ? '${mins ~/ 60} h ago'
              : '${mins ~/ (60 * 24)} d ago';
  return 'On, only you can see it. Backed up $when.';
}
