/// EPI Supervisor Platform — Application Exceptions
/// Centralized exception hierarchy for the entire system.
library;

// ─── Base Exception ────────────────────────────────────────────────────────
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() =>
      'AppException: $message${code != null ? ' [$code]' : ''}';
}

// ─── API Exceptions ────────────────────────────────────────────────────────
class ApiException extends AppException {
  const ApiException(super.message, {super.code, super.details});
}

class NotFoundException extends AppException {
  const NotFoundException(super.message) : super(code: '404');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized'])
      : super(code: '401');
}

class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Forbidden']) : super(code: '403');
}

class ConflictException extends AppException {
  const ConflictException(super.message) : super(code: '409');
}

class FileStorageException extends AppException {
  FileStorageException([String message = 'فشل في رفع أو تحميل الملف'])
      : super(message, code: 'storage_error');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Internal server error'])
      : super(code: '500');
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection'])
      : super(code: 'NETWORK');
}

// ─── Auth Exceptions ───────────────────────────────────────────────────────
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException()
      : super('Invalid email or password', code: 'INVALID_CREDENTIALS');
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException()
      : super('Session expired, please login again', code: 'SESSION_EXPIRED');
}

// ─── Permission Exceptions ─────────────────────────────────────────────────
class PermissionException extends AppException {
  const PermissionException(super.message) : super(code: 'PERMISSION_DENIED');
}

// ─── Offline/Sync Exceptions ───────────────────────────────────────────────
class OfflineException extends AppException {
  const OfflineException([super.message = 'Device is offline'])
      : super(code: 'OFFLINE');
}

class SyncException extends AppException {
  const SyncException(super.message, {super.code});
}

class ConflictResolutionException extends SyncException {
  const ConflictResolutionException(super.message)
      : super(code: 'SYNC_CONFLICT');
}

// ─── Storage Exceptions ────────────────────────────────────────────────────
class StorageException extends AppException {
  const StorageException(super.message, {super.code = 'STORAGE_ERROR'});
}

// ─── Validation Exceptions ─────────────────────────────────────────────────
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(super.message, {this.fieldErrors})
      : super(code: 'VALIDATION_ERROR');
}

// ─── AI Exceptions ────────────────────────────────────────────────────────
class AIException extends AppException {
  const AIException(super.message, {super.code = 'AI_ERROR'});
}
