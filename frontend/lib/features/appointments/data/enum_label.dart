/// Turns a wire enum name into a readable label.
String humanizeEnum(String value) {
  return value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0]}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
