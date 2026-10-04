/// Every failed API call surfaces as this. [code] is the backend's stable error code
/// (e.g. `invalid_credentials`, `email_not_confirmed`, `validation_failed`) or one of the client-side codes
/// below; [message] is ready to show to the user.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  static const networkError = 'network_error';
  static const timeout = 'timeout';
  static const unknown = 'unknown';

  final String code;
  final String message;
  final int? statusCode;

  /// Per-field messages for `validation_failed`, keyed by the camelCase field name (`email`, `password`, ...).
  final Map<String, List<String>> fieldErrors;

  final int? retryAfterSeconds;

  /// First message for [field], for `InputDecoration.errorText`.
  String? fieldError(String field) {
    final messages = fieldErrors[field];
    return messages == null || messages.isEmpty ? null : messages.first;
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
