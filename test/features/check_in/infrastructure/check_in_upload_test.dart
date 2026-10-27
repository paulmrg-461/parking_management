import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Success: a path collision counts as an already-uploaded photo', () {
    expect(
      isDuplicateUpload(
        const StorageException(
          'The resource already exists',
          statusCode: '409',
          error: 'Duplicate',
        ),
      ),
      isTrue,
    );
  });

  test('Failure: an unexpected storage error is not swallowed', () {
    expect(
      isDuplicateUpload(
        const StorageException('Bad request', statusCode: '400'),
      ),
      isFalse,
    );
  });

  test('Security: a permission failure never looks like a duplicate', () {
    expect(
      isDuplicateUpload(
        const StorageException(
          'Unauthorized',
          statusCode: '403',
          error: 'AccessDenied',
        ),
      ),
      isFalse,
    );
  });
}
