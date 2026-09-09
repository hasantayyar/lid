public enum ActionIntent: Sendable, Hashable, Equatable {
    case apply(ActionID)
    case reset(ActionID)
}

public enum ActionIntentOrdering {
    public static let applyOrder: [ActionID] = [
        .privacyOverlay,
        .mediaPause,
        .lock,
    ]
}
