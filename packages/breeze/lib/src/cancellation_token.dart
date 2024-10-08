import 'dart:async';

/// A token which can be used for receiving cancellation notification.
class CancellationToken {
  static final CancellationTokenSource _defaut = CancellationTokenSource();

  /// Gets a [CancellationToken] which will never gets canceled.
  static CancellationToken get none => _defaut.token;

  final CancellationTokenSource _cts;
  CancellationToken._(this._cts);

  /// Checks whether current [CancellationToken] is already canceled.
  bool get isCancellationRequested => _cts.isCancellationRequested;

  /// Gets a [Future] object which will complete when current [CancellationToken] gets canceled.
  Future<void> get future => _cts._completer.future;

  /// Throws an [OperationCanceledException] if current [CancellationToken] is already canceled.
  void throwIfCancellationRequested() {
    if (isCancellationRequested) {
      throw OperationCanceledException(this);
    }
  }
}

/// Signals to a [CancellationToken] that it should be canceled.
///
/// [CancellationTokenSource] is used to instantiate a [CancellationToken] (via
/// the source's [token] property) that can be handed to operations that wish to be
/// notified of cancellation or that can be used to register asynchronous operations for cancellation.
/// That token may have cancellation requested by calling to the source's [cancel] method.
class CancellationTokenSource {
  final _completer = Completer<void>();
  late final CancellationToken _token;

  CancellationTokenSource() {
    _token = CancellationToken._(this);
  }

  /// Creates a [CancellationTokenSource] which get canceled when any of
  /// the [CancellationToken] in [tokens] is canceled.
  factory CancellationTokenSource.linked(List<CancellationToken> tokens) {
    final cts = CancellationTokenSource();
    Future.any(tokens.map((e) => e.future)).then((value) => cts.cancel());
    return cts;
  }

  /// Checks whether current [CancellationToken] is already canceled.
  bool get isCancellationRequested => _completer.isCompleted;

  /// Gets a [CancellationToken] which can be used for receiving cancellation notification produced
  /// by current [CancellationTokenSource].
  CancellationToken get token => _token;

  /// Communicates a request for cancellation.
  /// 
  /// The associated [CancellationToken] will be notified of the cancellation
  /// and will transition to a state where [CancellationToken.isCancellationRequested] returns true.
  void cancel() {
    if (!isCancellationRequested) {
      _completer.complete();
    }
  }
}

/// Exception thrown when an operation is canceled by a [CancellationToken].
class OperationCanceledException implements Exception {
  /// The [CancellationToken] which caused the cancellation.
  final CancellationToken token;
  OperationCanceledException(this.token);
}

extension FutureExtension<T> on Future<T> {
  /// Waits until the future is completed or the [cancellationToken] gets canceled.
  /// 
  /// If [cancellationToken] gets canceled during the wait, an [OperationCanceledException] is thrown.
  /// 
  /// Please note that this method just cancel wait operation rather than canceling the underlying operation.
  /// To cancel the underly operation, you must pass the [cancellationToken]
  /// to the underlying operation and make sure it handles the cancellation request properly.
  Future<T> wait(CancellationToken cancellationToken) async {
    final result = await Future.any<dynamic>([this, cancellationToken.future]);
    cancellationToken.throwIfCancellationRequested();
    return result as T;
  }

  /// Waits for the completion of the future and discards its result (including error).
  Future<void> waitForCompletion() async {
    try {
      await Future.wait([this]);
    } catch (_) {}
  }
}
