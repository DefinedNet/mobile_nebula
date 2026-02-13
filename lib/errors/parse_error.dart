class ParseError implements Exception {
  String message;
  ParseError(this.message);

  @override
  String toString() => 'ParseError: $message';
}
