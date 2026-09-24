import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteCampaignStatus { draft, active, ended, cancelled }

VoteCampaignStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'active':
      return VoteCampaignStatus.active;
    case 'ended':
      return VoteCampaignStatus.ended;
    case 'cancelled':
      return VoteCampaignStatus.cancelled;
    default:
      return VoteCampaignStatus.draft;
  }
}

String _statusToString(VoteCampaignStatus status) {
  switch (status) {
    case VoteCampaignStatus.active:
      return 'active';
    case VoteCampaignStatus.ended:
      return 'ended';
    case VoteCampaignStatus.cancelled:
      return 'cancelled';
    case VoteCampaignStatus.draft:
      return 'draft';
  }
}

/// Campagne de vote payant créée par une organisation (élection Miss/
/// Mister, concours, etc.). Stockée dans Firestore, collection
/// `voteCampaigns`. Ses catégories vivent dans la sous-collection
/// `voteCampaigns/{id}/categories` (voir [VoteCategory]), chacune avec
/// ses propres candidats.
class VoteCampaign {
  final String id;
  final String organisationId;
  final String organisationName;
  final String ownerId;

  final String title;
  final String description;
  final String? coverImageUrl;

  final DateTime? startsAt;
  final DateTime? endsAt;

  final VoteCampaignStatus status;
  final DateTime? createdAt;

  /// Voir [Event.organisationCertified] / [Event.hiddenByAdmin].
  final bool organisationCertified;
  final bool hiddenByAdmin;

  const VoteCampaign({
    required this.id,
    required this.organisationId,
    required this.organisationName,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.coverImageUrl,
    this.startsAt,
    this.endsAt,
    this.status = VoteCampaignStatus.draft,
    this.createdAt,
    this.organisationCertified = false,
    this.hiddenByAdmin = false,
  });

  bool get isOpenForVoting {
    if (status != VoteCampaignStatus.active) return false;
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  factory VoteCampaign.fromMap(String id, Map<String, dynamic> map) {
    final rawStartsAt = map['startsAt'];
    final rawEndsAt = map['endsAt'];
    final rawCreatedAt = map['createdAt'];
    return VoteCampaign(
      id: id,
      organisationId: map['organisationId'] as String? ?? '',
      organisationName: map['organisationName'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String?,
      startsAt: rawStartsAt is Timestamp ? rawStartsAt.toDate() : null,
      endsAt: rawEndsAt is Timestamp ? rawEndsAt.toDate() : null,
      status: _statusFromString(map['status'] as String?),
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      organisationCertified: map['organisationCertified'] as bool? ?? false,
      hiddenByAdmin: map['hiddenByAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organisationId': organisationId,
      'organisationName': organisationName,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'startsAt': startsAt == null ? null : Timestamp.fromDate(startsAt!),
      'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt!),
      'status': _statusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'organisationCertified': organisationCertified,
      'hiddenByAdmin': hiddenByAdmin,
    };
  }
}
