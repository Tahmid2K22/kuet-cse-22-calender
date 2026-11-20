/// Abstraction over the event source.
///
/// [SheetsService] is the production implementation; tests provide a fake so
/// the repository and UI can be verified without network access.
abstract class CalendarDataSource {
  /// Returns one map per sheet row, keyed by the lowercase column names
  /// (`date`, `time`, `title`, `type`, `description`, `location`).
  Future<List<Map<String, dynamic>>> fetchRows();

  /// Releases any resources owned by the source.
  void dispose() {}
}
