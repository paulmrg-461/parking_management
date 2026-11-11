/// How the operator resolved a version conflict.
sealed class ConflictResolution {
  const ConflictResolution();
}

/// Drop my change and keep what the server has.
final class KeepTheirs extends ConflictResolution {
  const KeepTheirs();
}

/// Re-send every field I changed on top of the version the server has now.
final class KeepMine extends ConflictResolution {
  const KeepMine();
}

/// Re-send the fields that merge cleanly plus the conflicting fields where the
/// operator chose "mine". A field missing from [mineFields] keeps the server's
/// value.
final class MergeFields extends ConflictResolution {
  const MergeFields(this.mineFields);

  final Set<String> mineFields;
}

/// My queued delete wins over someone else's edit: delete the row anyway.
final class KeepDelete extends ConflictResolution {
  const KeepDelete();
}

/// My edit loses to someone else's delete: drop it and the cached row.
final class AcceptDeletion extends ConflictResolution {
  const AcceptDeletion();
}
