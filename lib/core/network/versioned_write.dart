import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/failure.dart';
import 'supabase_error_mapper.dart';

/// Writes one row with optimistic concurrency: the caller sends the version it
/// edited from and a stale base is a conflict, never a silent overwrite.
///
/// * `baseVersion == null` (an older cached row): the filter is not sent and a
///   zero-row result keeps its old meaning (`NotFoundError`).
/// * zero rows, the row exists with another version: [VersionConflictFailure]
///   carrying the server row so the caller can merge or ask.
/// * zero rows, the row is gone: [VersionConflictFailure] with a null row.
/// * zero rows, the row still has the base version: the write was hidden by
///   RLS or another condition → `PermissionDeniedError`.
Future<Map<String, dynamic>> updateVersioned(
  SupabaseClient client,
  String table, {
  required Map<String, dynamic> payload,
  required Map<String, Object> match,
  int? baseVersion,
  int? lotHeader,
}) async {
  try {
    var query = client.from(table).update(payload);
    if (baseVersion != null) {
      query = query.eq('version', baseVersion);
    }
    for (final entry in match.entries) {
      query = query.eq(entry.key, entry.value);
    }
    if (lotHeader != null) {
      query = query.setHeader('x-lot-id', '$lotHeader');
    }
    final rows = await query.select();
    if (rows.length == 1) {
      return Map<String, dynamic>.from(rows.first);
    }
    throw await _conflictOrMissing(
      client,
      table,
      match: match,
      baseVersion: baseVersion,
      lotHeader: lotHeader,
    );
  } on Failure {
    // The conflict/permission failures built above are already typed.
    rethrow;
  } catch (error) {
    throw mapSupabaseError(error);
  }
}

/// Deletes one row with the same optimistic rule. A row that is already gone
/// is a success (the intent holds); an edit by someone else is a conflict.
Future<void> deleteVersioned(
  SupabaseClient client,
  String table, {
  required Map<String, Object> match,
  int? baseVersion,
  int? lotHeader,
}) async {
  try {
    var query = client.from(table).delete();
    if (baseVersion != null) {
      query = query.eq('version', baseVersion);
    }
    for (final entry in match.entries) {
      query = query.eq(entry.key, entry.value);
    }
    if (lotHeader != null) {
      query = query.setHeader('x-lot-id', '$lotHeader');
    }
    final rows = await query.select();
    if (rows.length == 1) {
      return;
    }
    if (baseVersion == null) {
      return;
    }
    final server = await _readRow(
      client,
      table,
      match: match,
      lotHeader: lotHeader,
    );
    if (server == null) {
      return;
    }
    throw VersionConflictFailure(server);
  } on Failure {
    // The conflict/permission failures built above are already typed.
    rethrow;
  } catch (error) {
    throw mapSupabaseError(error);
  }
}

/// Reads the row the [match] points at (same RLS and header), or null.
Future<Map<String, dynamic>?> _readRow(
  SupabaseClient client,
  String table, {
  required Map<String, Object> match,
  int? lotHeader,
}) async {
  var query = client.from(table).select();
  for (final entry in match.entries) {
    query = query.eq(entry.key, entry.value);
  }
  if (lotHeader != null) {
    query = query.setHeader('x-lot-id', '$lotHeader');
  }
  final rows = await query;
  return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
}

/// Decides what a zero-row write means: not found (legacy), conflict with the
/// row the server has now, or a write hidden by RLS.
Future<Failure> _conflictOrMissing(
  SupabaseClient client,
  String table, {
  required Map<String, Object> match,
  required int? baseVersion,
  required int? lotHeader,
}) async {
  final server = await _readRow(
    client,
    table,
    match: match,
    lotHeader: lotHeader,
  );
  if (baseVersion == null) {
    return server == null
        ? const ValidationFailure('Not found', 'NotFoundError')
        : const ValidationFailure('Forbidden', 'PermissionDeniedError');
  }
  if (server == null) {
    return const VersionConflictFailure(null);
  }
  if ((server['version'] as num?)?.toInt() != baseVersion) {
    return VersionConflictFailure(server);
  }
  return const ValidationFailure('Forbidden', 'PermissionDeniedError');
}
