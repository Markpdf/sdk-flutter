/// Base class for every error thrown by the markpdf SDK.
class MarkpdfException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  MarkpdfException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => 'MarkpdfException($statusCode): $message';
}

/// HTTP 400 - malformed body or URL.
class BadRequestException extends MarkpdfException {
  BadRequestException(super.message, {super.statusCode, super.detail});
}

/// HTTP 401 - missing or invalid API key.
class AuthenticationException extends MarkpdfException {
  AuthenticationException(super.message, {super.statusCode, super.detail});
}

/// HTTP 403 - unauthorized access or disallowed URL host.
class ForbiddenException extends MarkpdfException {
  ForbiddenException(super.message, {super.statusCode, super.detail});
}

/// HTTP 413 - document too large, too many pages, or ZIP out of bounds.
class PayloadTooLargeException extends MarkpdfException {
  PayloadTooLargeException(super.message, {super.statusCode, super.detail});
}

/// HTTP 415 - unsupported input format or Content-Encoding.
class UnsupportedFormatException extends MarkpdfException {
  UnsupportedFormatException(super.message, {super.statusCode, super.detail});
}

/// HTTP 422 - missing required parameters.
class UnprocessableEntityException extends MarkpdfException {
  UnprocessableEntityException(super.message, {super.statusCode, super.detail});
}

/// HTTP 429 - too many requests. Retry with backoff.
class RateLimitException extends MarkpdfException {
  RateLimitException(super.message, {super.statusCode, super.detail});
}

/// HTTP 500 - conversion failed.
class ConversionException extends MarkpdfException {
  ConversionException(super.message, {super.statusCode, super.detail});
}

/// A queued job (202 -> /jobs/{id}) finished with status=failed.
class JobFailedException extends MarkpdfException {
  JobFailedException(super.message, {super.statusCode, super.detail});
}

MarkpdfException errorForStatus(int statusCode, Object? detail) {
  final message = (detail is Map && detail['detail'] != null)
      ? detail['detail'].toString()
      : detail?.toString() ?? 'HTTP $statusCode';

  switch (statusCode) {
    case 400:
      return BadRequestException(message, statusCode: statusCode, detail: detail);
    case 401:
      return AuthenticationException(message, statusCode: statusCode, detail: detail);
    case 403:
      return ForbiddenException(message, statusCode: statusCode, detail: detail);
    case 413:
      return PayloadTooLargeException(message, statusCode: statusCode, detail: detail);
    case 415:
      return UnsupportedFormatException(message, statusCode: statusCode, detail: detail);
    case 422:
      return UnprocessableEntityException(message, statusCode: statusCode, detail: detail);
    case 429:
      return RateLimitException(message, statusCode: statusCode, detail: detail);
    case 500:
      return ConversionException(message, statusCode: statusCode, detail: detail);
    default:
      return MarkpdfException(message, statusCode: statusCode, detail: detail);
  }
}
