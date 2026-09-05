class CreateVehicleCommand {
  const CreateVehicleCommand({
    required this.plate,
    required this.categoryId,
    this.color,
    this.brand,
  });

  final String plate;
  final int categoryId;
  final String? color;
  final String? brand;
}
