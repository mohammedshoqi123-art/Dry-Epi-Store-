/// Campaign/activity types supported by EPI Supervisor.
enum CampaignType {
  polioCampaign('polio_campaign', 'حملة شلل الأطفال', '🧬'),
  integratedActivity('integrated_activity', 'النشاط الإيصالي التكاملي', '📋');

  final String value;
  final String labelAr;
  final String emoji;

  const CampaignType(this.value, this.labelAr, this.emoji);

  static CampaignType fromString(String value) {
    return CampaignType.values.firstWhere(
      (c) => c.value == value,
      orElse: () => CampaignType.polioCampaign,
    );
  }

  /// Returns a display string with emoji.
  String get displayLabel => '$emoji $labelAr';
}
