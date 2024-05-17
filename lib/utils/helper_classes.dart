class SocialAccount {
  final String platform;
  final String id;

  SocialAccount({required this.platform, required this.id});

  factory SocialAccount.fromMap(Map<String, dynamic> map) {
    return SocialAccount(
      platform: map['platform'] as String,
      id: map['id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'id': id,
    };
  }
}
