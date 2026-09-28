import '../../../core/l10n/l10n.dart';
import '../../auth/domain/entities/user.dart';

extension UserRoleLabel on UserRole {
  String label(AppLocalizations l10n) => switch (this) {
    UserRole.admin => l10n.roleAdmin,
    UserRole.operator => l10n.roleOperator,
  };
}
