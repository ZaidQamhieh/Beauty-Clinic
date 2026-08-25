/// Font roles. Swap the pairing here only.
abstract class AppFonts {
  /// Screen titles, treatment names, prices, stat figures.
  static const String display = 'Constantia';
  static const List<String> displayFallback = [
    'Georgia',
    'Times New Roman',
    'serif',
  ];

  /// Paragraphs, form fields, list rows, buttons.
  static const String body = 'Corbel';
  static const List<String> bodyFallback = [
    'Segoe UI',
    'system-ui',
    '-apple-system',
    'Roboto',
    'Helvetica Neue',
    'sans-serif',
  ];

  /// Arabic headings and body.
  static const String arabic = 'Sakkal Majalla';
  static const List<String> arabicFallback = [
    'Traditional Arabic',
    'Noto Naskh Arabic',
    'Geeza Pro',
    'Segoe UI',
    'serif',
  ];
}
