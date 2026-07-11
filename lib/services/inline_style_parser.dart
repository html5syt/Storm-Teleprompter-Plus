/// Parses the small subset of inline CSS used by stored rich-text articles.
abstract final class InlineStyleParser {
  static final RegExp _colorValuePattern = RegExp(
    r'(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?|rgba?\([^)]*\))',
    caseSensitive: false,
  );

  /// Returns an exact color property value from [style].
  ///
  /// Property names are matched at declaration boundaries, so querying
  /// `color` never matches the `color` suffix in `background-color`.
  static String? color(String style, String property) {
    final propertyPattern = RegExp.escape(property);
    final declaration = RegExp(
      '(?:^|;)\\s*$propertyPattern\\s*:\\s*'
      '(${_colorValuePattern.pattern})\\s*(?=;|\$)',
      caseSensitive: false,
    ).firstMatch(style);
    return declaration?.group(1);
  }
}
