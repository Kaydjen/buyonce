/// Which limit stopped a model.
enum LimitScope { minute, day, unknown }

/// What one Gemini request ended with. A task (names from a photo, later a receipt) maps
/// each case to a message for the user.
sealed class GeminiOutcome {
  const GeminiOutcome();
}

/// The model's answer text (JSON or plain) and the model that gave it.
final class GeminiOk extends GeminiOutcome {
  const GeminiOk(this.text, this.model);
  final String text;
  final String model;
}

/// No key is stored on this device.
final class GeminiNoKey extends GeminiOutcome {
  const GeminiNoKey();
}

/// Google refused the key (not valid, revoked, no permission).
final class GeminiBadKey extends GeminiOutcome {
  const GeminiBadKey();
}

/// The phone cannot reach Google.
final class GeminiOffline extends GeminiOutcome {
  const GeminiOffline();
}

/// The only usable model has reached its limit. The user can add more models, or wait
/// [retryIn] (null when unknown).
final class GeminiLimited extends GeminiOutcome {
  const GeminiLimited(this.model, this.scope, this.retryIn);
  final String model;
  final LimitScope scope;
  final Duration? retryIn;
}

/// Every usable model of the list has reached its limit; [retryIn] is the shortest wait.
final class GeminiAllLimited extends GeminiOutcome {
  const GeminiAllLimited(this.retryIn);
  final Duration? retryIn;
}

/// Overload, an empty answer, an unknown model, an empty list: nothing worked and it is
/// not a limit.
final class GeminiFailed extends GeminiOutcome {
  const GeminiFailed();
}
