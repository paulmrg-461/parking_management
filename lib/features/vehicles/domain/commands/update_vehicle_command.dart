class UpdateVehicleCommand {
  const UpdateVehicleCommand({
    required this.id,
    this.categoryId,
    this.color,
    this.brand,
  });

  final int id;
  final int? categoryId;
  final String? color;
  final String? brand;
}
