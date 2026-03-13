class ShippingAddressEntity {
  const ShippingAddressEntity({
    required this.id,
    required this.userId,
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.stateRegion,
    required this.postalCode,
    required this.countryCode,
    this.line2,
    this.deliveryNotes,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String stateRegion;
  final String postalCode;
  final String countryCode;
  final String? deliveryNotes;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get summaryLine => [
    line1,
    if ((line2 ?? '').trim().isNotEmpty) line2!.trim(),
    city,
    stateRegion,
    postalCode,
    countryCode,
  ].join(', ');

  ShippingAddressEntity copyWith({
    String? id,
    String? userId,
    String? recipientName,
    String? phone,
    String? line1,
    String? line2,
    String? city,
    String? stateRegion,
    String? postalCode,
    String? countryCode,
    String? deliveryNotes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShippingAddressEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      stateRegion: stateRegion ?? this.stateRegion,
      postalCode: postalCode ?? this.postalCode,
      countryCode: countryCode ?? this.countryCode,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
