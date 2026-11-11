/// How the operator resolved a version conflict.
enum ConflictChoice {
  /// Re-send my change on top of the version the server has now.
  keepMine,

  /// Drop my change and keep what the server has.
  keepTheirs,
}
