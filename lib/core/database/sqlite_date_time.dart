int dateTimeToSqlite(DateTime value) => value.microsecondsSinceEpoch;

DateTime dateTimeFromSqlite(Object value) {
  if (value is! int) {
    throw FormatException('Expected a SQLite timestamp in microseconds.');
  }
  return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
}
