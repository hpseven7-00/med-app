int dateTimeToSqlite(DateTime value) {
  return value.microsecondsSinceEpoch;
}

DateTime dateTimeFromSqlite(Object value) {
  if (value is int) {
    return DateTime.fromMicrosecondsSinceEpoch(value);
  }

  throw FormatException(
    'Expected a SQLite timestamp in microseconds.',
  );
}