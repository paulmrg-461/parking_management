import 'package:equatable/equatable.dart';

/// First-steps checklist of the active site (`rpc/lot_setup_status`). A site
/// cannot register vehicles until it has categories, tariffs and capacity (or
/// a physical map), and its receipts/QR pages need an address and phone.
class LotSetupStatus extends Equatable {
  const LotSetupStatus({
    this.known = true,
    this.categories = 0,
    this.tariffs = 0,
    this.carCapacity = 0,
    this.motoCapacity = 0,
    this.spots = 0,
    this.hasAddress = false,
    this.hasPhone = false,
  });

  /// The RPC failed: hide the card instead of claiming the site is unset.
  static const unknown = LotSetupStatus(known: false);

  static const totalSteps = 4;

  final bool known;
  final int categories;
  final int tariffs;
  final int carCapacity;
  final int motoCapacity;
  final int spots;
  final bool hasAddress;
  final bool hasPhone;

  bool get hasCategories => categories > 0;
  bool get hasTariffs => tariffs > 0;
  bool get hasCapacity => carCapacity > 0 || motoCapacity > 0 || spots > 0;
  bool get hasIdentity => hasAddress && hasPhone;

  bool get complete =>
      hasCategories && hasTariffs && hasCapacity && hasIdentity;

  int get doneSteps => [
    hasCategories,
    hasTariffs,
    hasCapacity,
    hasIdentity,
  ].where((done) => done).length;

  factory LotSetupStatus.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return LotSetupStatus(
      categories: value(json['categories']),
      tariffs: value(json['tariffs']),
      carCapacity: value(json['car_capacity']),
      motoCapacity: value(json['moto_capacity']),
      spots: value(json['spots']),
      hasAddress: json['has_address'] == true,
      hasPhone: json['has_phone'] == true,
    );
  }

  @override
  List<Object?> get props => [
    known,
    categories,
    tariffs,
    carCapacity,
    motoCapacity,
    spots,
    hasAddress,
    hasPhone,
  ];
}
