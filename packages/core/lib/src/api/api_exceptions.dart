class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic details;

  const ApiException(this.message, {this.code, this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message${code != null ? ' (code: $code)' : ''}';

  bool get isUnauthorized => code == '401' || statusCode == 401;
  bool get isForbidden => code == '403' || statusCode == 403;
  bool get isNotFound => code == '404' || statusCode == 404;
  bool get isRateLimited => code == '429' || statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}
