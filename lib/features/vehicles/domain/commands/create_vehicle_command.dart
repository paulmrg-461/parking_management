class CreateVehicleCommand {
  const CreateVehicleCommand({
    required this.plate,
    required this.categoryId,
    this.color,
    this.brand,
    this.ownerPhone,
    this.ownerName,
  });

  final String plate;
  final int categoryId;
  final String? color;
  final String? brand;
  final String? ownerPhone;
  final String? ownerName;
}
