import 'result.dart';

extension ResultX<T> on Result<T> {
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Failure(:final error) => Failure(error),
  };
}

extension FutureResultX<T> on Future<Result<T>> {
  Future<Result<R>> map<R>(R Function(T value) transform) async =>
      (await this).map(transform);

  /// Runs [next] with the value on success; passes a failure through.
  Future<Result<R>> andThen<R>(
    Future<Result<R>> Function(T value) next,
  ) async => switch (await this) {
    Ok(:final value) => next(value),
    Failure(:final error) => Failure(error),
  };
}
