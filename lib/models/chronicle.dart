enum ChronicleRole { player, storyteller }

class Chronicle {
  final String id;
  String name;
  ChronicleRole role;
  int updatedAt;
  String? driveFolderId;
  String? inviteLink;
  String? playerDisplayName;
  String? playerFolderId;

  Chronicle({
    required this.id,
    this.name = '',
    this.role = ChronicleRole.player,
    int? updatedAt,
    this.driveFolderId,
    this.inviteLink,
    this.playerDisplayName,
    this.playerFolderId,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'updatedAt': updatedAt,
        'driveFolderId': driveFolderId,
        'inviteLink': inviteLink,
        'playerDisplayName': playerDisplayName,
        'playerFolderId': playerFolderId,
      };

  factory Chronicle.fromJson(Map<String, dynamic> json) {
    final roleRaw = json['role']?.toString() ?? 'player';
    return Chronicle(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: roleRaw == 'storyteller'
          ? ChronicleRole.storyteller
          : ChronicleRole.player,
      updatedAt: json['updatedAt'] ?? 0,
      driveFolderId: json['driveFolderId'],
      inviteLink: json['inviteLink'],
      playerDisplayName: json['playerDisplayName'],
      playerFolderId: json['playerFolderId'],
    );
  }
}
