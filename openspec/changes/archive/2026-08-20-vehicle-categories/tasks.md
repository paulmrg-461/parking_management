## 1. Backend domain and persistence

- [x] 1.1 Add `Category` domain entity and name validation in `app/domain`
- [x] 1.2 Add `CategoryModel` and Alembic migration for the `categories` table
- [x] 1.3 Add `CategoryRepository` port and SQLAlchemy implementation
- [x] 1.4 Write 3 tests (Success / Failure / Security) for the category repository

## 2. Backend endpoints

- [x] 2.1 Add `CategoryService` (create/list/update/delete) in `app/application`
- [x] 2.2 Add `GET /categories` (authenticated) and admin-only `POST/PATCH/DELETE` endpoints
- [x] 2.3 Write 3 tests (Success / Failure / Security) for the category endpoints
- [x] 2.4 Run `pytest`; fix findings

## 3. Flutter domain and adapters

- [x] 3.1 Add `Category` entity and Hive adapter registration
- [x] 3.2 Add `CategoryRepository` port (list, create, update, delete)
- [x] 3.3 Add remote (Dio) and local (Hive CE) data sources and the repository impl
- [x] 3.4 Register the feature in the DI container
- [x] 3.5 Write 3 tests (Success / Failure / Security) for the category repository

## 4. Flutter presentation and state

- [x] 4.1 Add `CategoriesCubit` with Equatable states
- [x] 4.2 Add the admin categories page (list, create, rename, delete)
- [x] 4.3 Add the `/categories` route and a home entry for admins
- [x] 4.4 Write 3 tests (Success / Failure / Security) for the cubit and page
- [x] 4.5 Run `flutter analyze` and `flutter test`; fix findings

## 5. Verification

- [x] 5.1 Confirm `pytest` passes
- [x] 5.2 Confirm `flutter analyze` and `flutter test` pass
- [x] 5.3 Confirm `openspec validate vehicle-categories` passes
