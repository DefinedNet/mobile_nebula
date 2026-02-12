class ParseError implements Exception {
  final String message;
  ParseError(this.message);

  @override
  String toString() => 'ParseError: $message';
}
