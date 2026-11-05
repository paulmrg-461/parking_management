class UpdateVehicleCommand {
  const UpdateVehicleCommand({
    required this.id,
    this.categoryId,
    this.color,
    this.brand,
    this.ownerPhone,
    this.ownerName,
  });

  final int id;
  final int? categoryId;
  final String? color;
  final String? brand;

  /// `null` keeps the stored value; an empty string clears it.
  final String? ownerPhone;

  /// `null` keeps the stored value; an empty string clears it.
  final String? ownerName;
}
