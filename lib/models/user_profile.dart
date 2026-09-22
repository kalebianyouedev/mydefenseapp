/// Profil utilisateur.
///
/// Sérialisé en JSON simple (String/DateTime ISO8601) pour rester
/// directement compatible avec une future table Supabase `profiles`.
class UserProfile {
  final String firstName;
  final String lastName;
  final String phone;
  final String city;
  final String address;
  final DateTime? birthDate;
  final String companyName;
  final String? photoUrl;
  final String? bannerUrl;

  const UserProfile({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.city = '',
    this.address = '',
    this.birthDate,
    this.companyName = '',
    this.photoUrl,
    this.bannerUrl,
  });

  String get fullName => [firstName, lastName]
      .where((e) => e.trim().isNotEmpty)
      .join(' ')
      .trim();

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawBirthDate = map['birthDate'];
    return UserProfile(
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      city: map['city'] as String? ?? '',
      address: map['address'] as String? ?? '',
      birthDate:
          rawBirthDate is String ? DateTime.tryParse(rawBirthDate) : null,
      companyName: map['companyName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'city': city,
      'address': address,
      'birthDate': birthDate?.toIso8601String(),
      'companyName': companyName,
      'photoUrl': photoUrl,
      'bannerUrl': bannerUrl,
    };
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? city,
    String? address,
    DateTime? birthDate,
    String? companyName,
    String? photoUrl,
    String? bannerUrl,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      birthDate: birthDate ?? this.birthDate,
      companyName: companyName ?? this.companyName,
      photoUrl: photoUrl ?? this.photoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
    );
  }
}
