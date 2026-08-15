abstract final class InlineStyleParser {
  static final RegExp _colorValuePattern = RegExp(
    r'(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?|rgba?\([^)]*\))',
    caseSensitive: false,
  );

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
