class Branch {
  final int id;
  final String name;
  final String? code;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? openingHours;
  final bool isPickupEnabled;
  final bool isDeliveryEnabled;

  Branch({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.city,
    this.phone,
    this.email,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.isPickupEnabled = true,
    this.isDeliveryEnabled = true,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      isPickupEnabled: json['is_pickup_enabled'] as bool? ?? true,
      isDeliveryEnabled: json['is_delivery_enabled'] as bool? ?? true,
    );
  }
}
