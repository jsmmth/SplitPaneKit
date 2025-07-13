import UIKit

/// Configuration for split pane animations
public struct SplitPaneAnimationSettings: Sendable {
    public let duration: TimeInterval
    public let damping: CGFloat
    public let initialVelocity: CGFloat
    public let options: UIView.AnimationOptions
    
    public init(
        duration: TimeInterval = 0.45,
        damping: CGFloat = 0.7,
        initialVelocity: CGFloat = 0.95,
        options: UIView.AnimationOptions = [.beginFromCurrentState, .allowUserInteraction]
    ) {
        self.duration = duration
        self.damping = damping
        self.initialVelocity = initialVelocity
        self.options = options
    }
    
    public static let `default` = SplitPaneAnimationSettings()
    public static let fast = SplitPaneAnimationSettings(duration: 0.25, damping: 0.9, initialVelocity: 0.8)
}

/// Shadow configuration for panes
public struct PaneShadowConfiguration: Sendable {
    public let color: UIColor
    public let opacity: Float
    public let radius: CGFloat
    public let offset: CGSize
    
    public init(
        color: UIColor = .black,
        opacity: Float = 0.1,
        radius: CGFloat = 10,
        offset: CGSize = CGSize(width: 0, height: -3)
    ) {
        self.color = color
        self.opacity = opacity
        self.radius = radius
        self.offset = offset
    }
    
    public static let `default` = PaneShadowConfiguration()
    public static let none = PaneShadowConfiguration(opacity: 0)
}

/// Configuration for split pane layout
@MainActor
public struct SplitPaneConfiguration {
    public var handleSize: CGSize
    public var handleColor: UIColor
    public var handleSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var bottomPaneBackgroundColor: UIColor
    public var topPaneBackgroundColor: UIColor
    public var animationSettings: SplitPaneAnimationSettings
    public var topPaneShadow: PaneShadowConfiguration?
    public var bottomPaneShadow: PaneShadowConfiguration?
    public var dragThreshold: CGFloat
    public var velocityThreshold: CGFloat
    public var defaultBreakpoint: SplitPaneBreakpoint
    public var rubberBandingStrength: CGFloat
    public var topPaneContent: SplitPaneContentView?
    public var bottomPaneContent: SplitPaneContentView?
    public var hapticFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    
    public init(
        handleSize: CGSize = CGSize(width: 56, height: 4),
        handleColor: UIColor = .label.withAlphaComponent(0.08),
        handleSpacing: CGFloat = 20,
        cornerRadius: CGFloat = 40,
        bottomPaneBackgroundColor: UIColor = .secondarySystemGroupedBackground,
        topPaneBackgroundColor: UIColor = .secondarySystemGroupedBackground,
        animationSettings: SplitPaneAnimationSettings = .default,
        topPaneShadow: PaneShadowConfiguration? = .default,
        bottomPaneShadow: PaneShadowConfiguration? = .default,
        dragThreshold: CGFloat = 70,
        velocityThreshold: CGFloat = 300,
        defaultBreakpoint: SplitPaneBreakpoint = .quarter,
        rubberBandingStrength: CGFloat = 0.7,
        topPaneContent: SplitPaneContentView? = nil,
        bottomPaneContent: SplitPaneContentView? = nil,
        hapticFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .light,
    ) {
        self.handleSize = handleSize
        self.handleColor = handleColor
        self.handleSpacing = handleSpacing
        self.cornerRadius = cornerRadius
        self.topPaneBackgroundColor = topPaneBackgroundColor
        self.bottomPaneBackgroundColor = bottomPaneBackgroundColor
        self.animationSettings = animationSettings
        self.topPaneShadow = topPaneShadow
        self.bottomPaneShadow = bottomPaneShadow
        self.dragThreshold = dragThreshold
        self.velocityThreshold = velocityThreshold
        self.defaultBreakpoint = defaultBreakpoint
        self.rubberBandingStrength = rubberBandingStrength
        self.topPaneContent = topPaneContent
        self.bottomPaneContent = bottomPaneContent
        self.hapticFeedbackStyle = hapticFeedbackStyle
    }
    
    public static let `default` = SplitPaneConfiguration()
}

/// Predefined breakpoints for common split configurations
public struct SplitPaneBreakpoint: Sendable, Equatable, Hashable {
    public let ratio: CGFloat
    public let name: String
    
    public init(ratio: CGFloat, name: String) {
        self.ratio = ratio
        self.name = name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ratio)
        hasher.combine(name)
    }
    
    // Common breakpoints
    public static let quarter = SplitPaneBreakpoint(ratio: 0.25, name: "quarter")
    public static let half = SplitPaneBreakpoint(ratio: 0.5, name: "half")
    public static let threeQuarters = SplitPaneBreakpoint(ratio: 0.75, name: "threeQuarters")
    public static let third = SplitPaneBreakpoint(ratio: 0.33, name: "third")
    public static let twoThirds = SplitPaneBreakpoint(ratio: 0.67, name: "twoThirds")
}

/// Protocol for views that want to receive pan gesture updates
@MainActor
public protocol SplitPanePanEffectingView: AnyObject {
    func splitPaneDidUpdateHeight(_ splitPane: SplitPaneView, height: CGFloat, progress: CGFloat, currentBreakpoint: SplitPaneBreakpoint?, nextBreakpoint: SplitPaneBreakpoint?)
    func splitPaneDidTransitionToBreakpoint(_ splitPane: SplitPaneView, breakpoint: SplitPaneBreakpoint)
}
