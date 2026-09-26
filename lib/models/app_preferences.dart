/// How the app is lit.
///
/// The panes are glass over a night sky, so [AppTheme.dark] is the default, but
/// a pharmacy counter at midday is the opposite of that and the light theme is a
/// real theme rather than an afterthought.
enum AppTheme {
  dark('Dark'),
  light('Light'),
  system('System');

  const AppTheme(this.label);

  /// Shown in the Appearance picker.
  final String label;

  /// The longer explanation, so the choice is obvious at a glance.
  String get blurb {
    switch (this) {
      case AppTheme.dark:
        return 'Glass over a night sky. The intended look, and the easiest on '
            'the eyes in a dim stockroom.';
      case AppTheme.light:
        return 'Glass over daylight. Higher contrast for a bright counter, and '
            'better on a projector when walking someone through the ledger.';
      case AppTheme.system:
        return 'Follows Windows. Switches with the time of day, and stays put '
            'when you override it elsewhere.';
    }
  }

  String get storageValue => name;

  /// Anything unrecognised falls back to the default rather than throwing, so a
  /// preference written by a future version of the app cannot lock someone out.
  static AppTheme fromStorage(String? value) {
    for (final theme in AppTheme.values) {
      if (theme.storageValue == value) return theme;
    }
    return AppTheme.dark;
  }
}

/// The choices that are about the app itself rather than about the pharmacy's
/// records. Kept separate from [PrintSettings] so that neither record has to
/// know about the other.
class AppPreferences {
  AppPreferences({this.theme = AppTheme.dark});

  final AppTheme theme;

  AppPreferences copyWith({AppTheme? theme}) =>
      AppPreferences(theme: theme ?? this.theme);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'theme': theme.storageValue,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      theme: AppTheme.fromStorage(json['theme'] as String?),
    );
  }
}
