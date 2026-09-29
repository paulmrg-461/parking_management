// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 0;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      deviceId: fields[0] == null ? '' : fields[0] as String,
      lastSyncAt: fields[1] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.lastSyncAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final typeId = 1;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: (fields[0] as num?)?.toInt(),
      username: fields[1] as String,
      displayName: fields[2] as String,
      role: fields[3] as UserRole,
      isActive: fields[4] == null ? true : fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final typeId = 2;

  @override
  UserRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRole.admin;
      case 1:
        return UserRole.operator;
      default:
        return UserRole.admin;
    }
  }

  @override
  void write(BinaryWriter writer, UserRole obj) {
    switch (obj) {
      case UserRole.admin:
        writer.writeByte(0);
      case UserRole.operator:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AuthSessionAdapter extends TypeAdapter<AuthSession> {
  @override
  final typeId = 3;

  @override
  AuthSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuthSession(user: fields[0] as User, token: fields[1] as String);
  }

  @override
  void write(BinaryWriter writer, AuthSession obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.user)
      ..writeByte(1)
      ..write(obj.token);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final typeId = 4;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: (fields[0] as num?)?.toInt(),
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TariffAdapter extends TypeAdapter<Tariff> {
  @override
  final typeId = 5;

  @override
  Tariff read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tariff(
      id: (fields[0] as num?)?.toInt(),
      categoryId: (fields[1] as num).toInt(),
      type: fields[2] as TariffType,
      amount: (fields[3] as num).toInt(),
      startTime: fields[4] as String?,
      endTime: fields[5] as String?,
      active: fields[6] == null ? true : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Tariff obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.active);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TariffAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TariffTypeAdapter extends TypeAdapter<TariffType> {
  @override
  final typeId = 6;

  @override
  TariffType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TariffType.hourly;
      case 1:
        return TariffType.daily;
      case 2:
        return TariffType.nightly;
      case 3:
        return TariffType.monthly;
      default:
        return TariffType.hourly;
    }
  }

  @override
  void write(BinaryWriter writer, TariffType obj) {
    switch (obj) {
      case TariffType.hourly:
        writer.writeByte(0);
      case TariffType.daily:
        writer.writeByte(1);
      case TariffType.nightly:
        writer.writeByte(2);
      case TariffType.monthly:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TariffTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VehicleAdapter extends TypeAdapter<Vehicle> {
  @override
  final typeId = 7;

  @override
  Vehicle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Vehicle(
      id: (fields[0] as num?)?.toInt(),
      plate: fields[1] as String,
      categoryId: (fields[2] as num).toInt(),
      color: fields[3] as String?,
      brand: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Vehicle obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.plate)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.brand);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MonthlyPassAdapter extends TypeAdapter<MonthlyPass> {
  @override
  final typeId = 8;

  @override
  MonthlyPass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyPass(
      id: (fields[0] as num?)?.toInt(),
      vehicleId: (fields[1] as num).toInt(),
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      amount: (fields[4] as num).toInt(),
      active: fields[5] == null ? true : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyPass obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vehicleId)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.active);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyPassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ParkingSettingsAdapter extends TypeAdapter<ParkingSettings> {
  @override
  final typeId = 9;

  @override
  ParkingSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ParkingSettings(
      name: fields[0] == null ? 'Parqueadero' : fields[0] as String,
      address: fields[1] == null ? '' : fields[1] as String,
      schedule: fields[2] == null ? '' : fields[2] as String,
      phone: fields[3] == null ? '' : fields[3] as String,
      website: fields[4] == null ? '' : fields[4] as String,
      whatsapp: fields[5] == null ? '' : fields[5] as String,
      logoVersion: fields[6] == null ? 0 : (fields[6] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ParkingSettings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.address)
      ..writeByte(2)
      ..write(obj.schedule)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.website)
      ..writeByte(5)
      ..write(obj.whatsapp)
      ..writeByte(6)
      ..write(obj.logoVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParkingSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
