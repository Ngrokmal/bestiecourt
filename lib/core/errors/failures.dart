import 'package:equatable/equatable.dart';

/// Base failure class for Clean Architecture domain/data boundaries.
/// Never leaks raw SQL errors, tokens, or stack traces to the UI.
sealed class AppFailure extends Equatable {
  const AppFailure({
    required this.message,
    this.code,
    this.isRetryable = false,
  });

  final String message;
  final String? code;
  final bool isRetryable;

  @override
  List<Object?> get props => <Object?>[message, code, isRetryable];
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'ইন্টারনেট সংযোগ পাওয়া যাচ্ছে না। অনুগ্রহ করে আবার চেষ্টা করুন।',
    super.code = 'NETWORK_ERROR',
    super.isRetryable = true,
  });
}

final class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.isRetryable = false,
  });
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.isRetryable = false,
  });
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    super.message = 'আপনার এই কাজটি করার অনুমতি নেই।',
    super.code = 'UNAUTHORIZED',
    super.isRetryable = false,
  });
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({
    super.message = 'অতিরিক্ত অনুরোধ করা হয়েছে। কিছুক্ষণ অপেক্ষা করে আবার চেষ্টা করুন।',
    super.code = 'RATE_LIMITED',
    super.isRetryable = true,
    this.retryAfterSeconds = 30,
  });

  final int retryAfterSeconds;

  @override
  List<Object?> get props => <Object?>[...super.props, retryAfterSeconds];
}

final class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message = 'সার্ভারে সাময়িক সমস্যা হয়েছে। অনুগ্রহ করে একটু পর চেষ্টা করুন।',
    super.code = 'SERVER_ERROR',
    super.isRetryable = true,
  });
}

/// Lightweight Result type for explicit success/failure handling across UseCases.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    final self = this;
    if (self is Success<T>) {
      return onSuccess(self.data);
    }
    return onFailure((self as FailureResult<T>).failure);
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final AppFailure failure;
}
