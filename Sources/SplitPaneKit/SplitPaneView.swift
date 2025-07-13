//
//  SplitPaneView.swift
//
//
//  Created by Joseph Smith on 13/07/2025.
//

import UIKit

@MainActor
public protocol SplitPaneViewDelegate: AnyObject {
    func splitPaneView(_ splitPaneView: SplitPaneView, didTransitionTo breakpoint: SplitPaneBreakpoint)
    func splitPaneView(_ splitPaneView: SplitPaneView, isDraggingWithTranslation translation: CGPoint, velocity: CGPoint)
}

@MainActor
public class SplitPaneView: UIView {
    // MARK: - Properties
    public weak var delegate: SplitPaneViewDelegate?
    private let panEffectingViews = NSHashTable<AnyObject>.weakObjects()
    private var isDraggingPane = false
    private var initialDragHeight: CGFloat = 0
    private var dismissalScrollViewGesture: UIPanGestureRecognizer?
    private var hasPerformedInitialLayout = false
    private var impactFeedback: UIImpactFeedbackGenerator?
    private var lastFeedbackBreakpoint: SplitPaneBreakpoint?
    private var displayLink: CADisplayLink?
    private var currentAnimator: UIViewPropertyAnimator?
    private var cachedBreakpointHeights: [SplitPaneBreakpoint: CGFloat] = [:]
    private var lastTopBounds: CGRect = .zero
    private var lastBottomBounds: CGRect = .zero
    private var contentPanGesture: UIPanGestureRecognizer?
    private var bottomContainerHeightConstraint: NSLayoutConstraint!
    private var bottomContainerTopConstraint: NSLayoutConstraint!
    
    public private(set) var configuration: SplitPaneConfiguration
    public private(set) var breakpoints: [SplitPaneBreakpoint] = []
    public private(set) var currentBreakpoint: SplitPaneBreakpoint
    public private(set) var topPaneContent: SplitPaneContentView?
    public private(set) var bottomPaneContent: SplitPaneContentView?
    
    // Cached height values
    private lazy var minHeight: CGFloat = {
        bounds.height * (breakpoints.first?.ratio ?? 0.1)
    }()
    private lazy var maxHeight: CGFloat = {
        bounds.height * (breakpoints.last?.ratio ?? 0.9)
    }()
    
    // MARK: - Views
    private let handle: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 2
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let handleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    public let topContainerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    public let bottomContainerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let draggableArea: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Init
    /// Initializes a new split pane view
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the split pane. Defaults to `.default`.
    public init(configuration: SplitPaneConfiguration = .default) {
        self.configuration = configuration
        self.currentBreakpoint = configuration.defaultBreakpoint
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.configuration = .default
        self.currentBreakpoint = configuration.defaultBreakpoint
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = .clear
        handle.backgroundColor = configuration.handleColor
        bottomContainerView.backgroundColor = configuration.bottomPaneBackgroundColor
        bottomContainerView.layer.cornerRadius = configuration.cornerRadius
        bottomContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        topContainerView.backgroundColor = configuration.topPaneBackgroundColor
        topContainerView.layer.cornerRadius = configuration.cornerRadius
        topContainerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        // Apply shadows if configured
        if let topShadow = configuration.topPaneShadow {
            applyShadow(to: topContainerView, configuration: topShadow)
        }
        
        if let bottomShadow = configuration.bottomPaneShadow {
            applyShadow(to: bottomContainerView, configuration: bottomShadow)
        }
        
        addSubview(topContainerView)
        addSubview(bottomContainerView)
        addSubview(handleContainer)
        handleContainer.addSubview(handle)
        bottomContainerView.addSubview(draggableArea)
        
        setupConstraints()
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        draggableArea.addGestureRecognizer(panGesture)
        let handlePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        handlePanGesture.delegate = self
        handleContainer.addGestureRecognizer(handlePanGesture)
        
        addPanEffectingView(self)  // Add self as a pan effecting view
        
        if let topContent = configuration.topPaneContent {
            setTopPaneContent(topContent)
        }
        
        if let bottomContent = configuration.bottomPaneContent {
            setBottomPaneContent(bottomContent)
        }
        
        if let hapticStyle = configuration.hapticFeedbackStyle {
            impactFeedback = UIImpactFeedbackGenerator(style: hapticStyle)
            impactFeedback?.prepare()
        }
    }
    
    private func applyShadow(to view: UIView, configuration: PaneShadowConfiguration) {
        view.layer.shadowColor = configuration.color.cgColor
        view.layer.shadowOpacity = configuration.opacity
        view.layer.shadowRadius = configuration.radius
        view.layer.shadowOffset = configuration.offset
        if configuration.opacity > 0 {
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale
        }
    }
    
    private func setupConstraints() {
        // Use a placeholder height initially
        /// Avoids any layout constraint warnings
        let initialHeight: CGFloat = 200
        
        bottomContainerHeightConstraint = bottomContainerView.heightAnchor.constraint(equalToConstant: initialHeight)
        bottomContainerTopConstraint = bottomContainerView.topAnchor.constraint(equalTo: topContainerView.bottomAnchor, constant: configuration.handleSpacing)
        bottomContainerHeightConstraint.priority = .required
        bottomContainerTopConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            topContainerView.topAnchor.constraint(equalTo: topAnchor),
            topContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            bottomContainerTopConstraint,
            bottomContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomContainerView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
            bottomContainerHeightConstraint,
            
            handleContainer.topAnchor.constraint(equalTo: topContainerView.bottomAnchor),
            handleContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            handleContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            handleContainer.heightAnchor.constraint(equalToConstant: configuration.handleSpacing),
            
            handle.widthAnchor.constraint(equalToConstant: configuration.handleSize.width),
            handle.heightAnchor.constraint(equalToConstant: configuration.handleSize.height),
            handle.centerXAnchor.constraint(equalTo: handleContainer.centerXAnchor),
            handle.centerYAnchor.constraint(equalTo: handleContainer.centerYAnchor),
            
            draggableArea.topAnchor.constraint(equalTo: bottomContainerView.topAnchor),
            draggableArea.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor),
            draggableArea.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor),
            draggableArea.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Public API
    /// Sets the content view for the top pane
    ///
    /// - Parameters:
    ///   - contentView: The content view to display in the top pane.
    ///
    /// - Note: If the content view conforms to `SplitPanePanEffectingView`, it will automatically
    ///   be registered to receive pan updates.
    public func setTopPaneContent(_ contentView: SplitPaneContentView) {
        topPaneContent?.removeFromSuperview()
        topPaneContent?.splitPaneView = nil
        topPaneContent = contentView
        contentView.splitPaneView = self
        topContainerView.addSubview(contentView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topContainerView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: topContainerView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: topContainerView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: topContainerView.bottomAnchor)
        ])
        
        if let panEffectingView = contentView as? SplitPanePanEffectingView {
            addPanEffectingView(panEffectingView)
        }
    }
    
    /// Sets the content view for the bottom pane
    ///
    /// - Parameters:
    ///   - contentView: The content view to display in the bottom pane.
    ///
    /// - Note: If the content view has a `dismissalHandlingScrollView`, appropriate gesture
    ///   recognizers will be set up to handle dragging from within the scroll view.
    public func setBottomPaneContent(_ contentView: SplitPaneContentView) {
        bottomPaneContent?.removeFromSuperview()
        bottomPaneContent?.splitPaneView = nil
        
        if let existingGesture = dismissalScrollViewGesture,
           let scrollView = bottomPaneContent?.dismissalHandlingScrollView {
            scrollView.removeGestureRecognizer(existingGesture)
            dismissalScrollViewGesture = nil
        }
        
        if let contentPanGesture = contentPanGesture {
            bottomPaneContent?.removeGestureRecognizer(contentPanGesture)
            self.contentPanGesture = nil
        }
        
        bottomPaneContent = contentView
        contentView.splitPaneView = self
        bottomContainerView.addSubview(contentView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: bottomContainerView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomContainerView.bottomAnchor)
        ])
        
        let contentPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        contentPanGesture.delegate = self
        contentView.addGestureRecognizer(contentPanGesture)
        self.contentPanGesture = contentPanGesture
        
        if let panEffectingView = contentView as? SplitPanePanEffectingView {
            addPanEffectingView(panEffectingView)
        }
        
        if let scrollView = contentView.dismissalHandlingScrollView {
            let scrollPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScrollViewPan(_:)))
            scrollPanGesture.delegate = self
            scrollView.addGestureRecognizer(scrollPanGesture)
            dismissalScrollViewGesture = scrollPanGesture
        }
    }
    
    /// Sets the available breakpoints for the split pane
    ///
    /// - Parameters:
    ///   - breakpoints: An array of breakpoints that define the possible positions for the split pane.
    ///
    /// - Note: The breakpoints will be automatically sorted by ratio in ascending order.
    ///   If the current default breakpoint doesn't exist in the new set, the closest one will be selected.
    public func setBreakpoints(_ breakpoints: [SplitPaneBreakpoint]) {
        self.breakpoints = breakpoints.sorted { $0.ratio < $1.ratio }
        cachedBreakpointHeights.removeAll()
        
        if !self.breakpoints.contains(where: { $0.ratio == configuration.defaultBreakpoint.ratio }) {
            // Find closest breakpoint to use as default
            if let closest = self.breakpoints.min(by: { abs($0.ratio - configuration.defaultBreakpoint.ratio) < abs($1.ratio - configuration.defaultBreakpoint.ratio) }) {
                self.currentBreakpoint = closest
            }
        }
        
        if bounds.height > 0 {
            updateHeight(animated: false)
        }
    }
    
    /// Registers a view to receive pan gesture updates
    ///
    /// - Parameters:
    ///   - view: A view conforming to `SplitPanePanEffectingView` that will receive updates
    ///           during pan gestures and breakpoint transitions.
    ///
    /// - Note: Views are held weakly and will be automatically removed when deallocated.
    public func addPanEffectingView(_ view: SplitPanePanEffectingView) {
        panEffectingViews.add(view as AnyObject)
    }
    
    /// Unregisters a view from receiving pan gesture updates
    ///
    /// - Parameters:
    ///   - view: The view to stop receiving pan updates.
    public func removePanEffectingView(_ view: SplitPanePanEffectingView) {
        panEffectingViews.remove(view as AnyObject)
    }
    
    /// Transitions the split pane to a specific breakpoint
    ///
    /// - Parameters:
    ///   - breakpoint: The target breakpoint to transition to.
    ///   - animated: Whether the transition should be animated. Defaults to `true`.
    ///
    /// - Note: This method will notify the delegate and all registered pan effecting views
    ///   of the transition. Haptic feedback will be provided if configured.
    public func transitionTo(breakpoint: SplitPaneBreakpoint, animated: Bool = true) {
        currentBreakpoint = breakpoint
        updateHeight(animated: animated)
        delegate?.splitPaneView(self, didTransitionTo: breakpoint)
        
        panEffectingViews.allObjects.compactMap { $0 as? SplitPanePanEffectingView }.forEach { view in
            view.splitPaneDidTransitionToBreakpoint(self, breakpoint: breakpoint)
        }
        
        provideHapticFeedback(for: breakpoint)
    }
    
    /// Calculates the current progress between breakpoints
    ///
    /// - Returns: A tuple containing:
    ///   - progress: A value between 0 and 1 representing the position between two breakpoints.
    ///   - current: The lower breakpoint, or nil if below all breakpoints.
    ///   - next: The upper breakpoint, or nil if above all breakpoints.
    ///
    /// - Note: This is useful for creating smooth animations or transitions based on the
    ///   current position of the split pane.
    public func progressBetweenBreakpoints() -> (progress: CGFloat, current: SplitPaneBreakpoint?, next: SplitPaneBreakpoint?) {
        guard bounds.height > 0 else { return (0.0, nil, nil) }
        
        let currentHeight = bottomContainerHeightConstraint.constant
        let currentRatio = currentHeight / bounds.height
        
        // Find which two breakpoints we're between
        var lower: SplitPaneBreakpoint?
        var upper: SplitPaneBreakpoint?
        
        for i in 0..<breakpoints.count {
            if breakpoints[i].ratio <= currentRatio {
                lower = breakpoints[i]
                if i + 1 < breakpoints.count {
                    upper = breakpoints[i + 1]
                }
            } else {
                break
            }
        }
        
        if let lower = lower, let upper = upper {
            let range = upper.ratio - lower.ratio
            if range > 0 {
                let progress = (currentRatio - lower.ratio) / range
                return (min(max(progress, 0), 1), lower, upper)
            } else {
                return (0.0, lower, upper)
            }
        } else if let lower = lower {
            return (1.0, lower, nil)
        } else if let first = breakpoints.first {
            return (0.0, nil, first)
        }
        
        return (0.0, nil, nil)
    }
    
    // MARK: - Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        if cachedBreakpointHeights.isEmpty || bounds.height != cachedBreakpointHeights.values.first {
            cachedBreakpointHeights = Dictionary(uniqueKeysWithValues:
                breakpoints.map { ($0, bounds.height * $0.ratio) }
            )
            
            minHeight = bounds.height * (breakpoints.first?.ratio ?? 0.1)
            maxHeight = bounds.height * (breakpoints.last?.ratio ?? 0.9)
        }
        
        if !hasPerformedInitialLayout && bounds.height > 0 {
            hasPerformedInitialLayout = true
            updateHeight(animated: false)
        }
        
        updateShadowPaths()
    }
    
    private func updateShadowPaths() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if configuration.topPaneShadow != nil {
            topContainerView.layer.shadowPath = UIBezierPath(
                roundedRect: topContainerView.bounds,
                cornerRadius: topContainerView.layer.cornerRadius
            ).cgPath
        }
        
        if configuration.bottomPaneShadow != nil {
            bottomContainerView.layer.shadowPath = UIBezierPath(
                roundedRect: bottomContainerView.bounds,
                cornerRadius: bottomContainerView.layer.cornerRadius
            ).cgPath
        }
        
        CATransaction.commit()
    }
    
    // MARK: - Private API
    private func updateHeight(animated: Bool) {
        guard bounds.height > 0 else { return }
        
        currentAnimator?.stopAnimation(true)
        let height = cachedBreakpointHeights[currentBreakpoint] ?? (bounds.height * currentBreakpoint.ratio)
        bottomContainerHeightConstraint.constant = height
        
        if animated {
            currentAnimator = UIViewPropertyAnimator(
                duration: configuration.animationSettings.duration,
                dampingRatio: configuration.animationSettings.damping
            ) { [weak self] in
                self?.layoutIfNeeded()
                self?.notifyPanEffectingViews()
            }
            currentAnimator?.startAnimation()
        } else {
            layoutIfNeeded()
            notifyPanEffectingViews()
        }
    }
    
    private func notifyPanEffectingViews() {
        let height = bottomContainerHeightConstraint.constant
        let currentTime = CACurrentMediaTime()
        
        let (progress, current, next) = progressBetweenBreakpoints()
        
        panEffectingViews.allObjects.compactMap { $0 as? SplitPanePanEffectingView }.forEach { view in
            view.splitPaneDidUpdateHeight(self, height: height, progress: progress, currentBreakpoint: current, nextBreakpoint: next)
        }
    }
    
    private func applyRubberBanding(to height: CGFloat, from currentHeight: CGFloat) -> CGFloat {
        guard bounds.height > 0 else { return height }
        
        if height < minHeight {
            let diff = minHeight - height
            let resistance = 1.0 - configuration.rubberBandingStrength
            return minHeight - (diff * resistance)
        } else if height > maxHeight {
            let diff = height - maxHeight
            let resistance = 1.0 - configuration.rubberBandingStrength
            return maxHeight + (diff * resistance)
        }
        
        return height
    }
    
    private func provideHapticFeedback(for breakpoint: SplitPaneBreakpoint) {
        guard let impactFeedback = impactFeedback,
              lastFeedbackBreakpoint != breakpoint else { return }
        
        lastFeedbackBreakpoint = breakpoint
        impactFeedback.impactOccurred()
    }
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            stopDisplayLink()
        }
    }
    
    @objc private func displayLinkTick() {
        if topContainerView.bounds != lastTopBounds || bottomContainerView.bounds != lastBottomBounds {
            lastTopBounds = topContainerView.bounds
            lastBottomBounds = bottomContainerView.bounds
            updateShadowPaths()
        }
    }
}

extension SplitPaneView: UIGestureRecognizerDelegate {
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        performPan(gesture: gesture)
    }
    
    @objc private func handleScrollViewPan(_ gesture: UIPanGestureRecognizer) {
        guard let scrollView = gesture.view as? UIScrollView else { return }
        let velocity = gesture.velocity(in: self)
        let topOffset = -scrollView.adjustedContentInset.top
        
        // Only handle if scroll view is at top and user is dragging down
        if scrollView.contentOffset.y <= topOffset && velocity.y > 0 {
            performPan(gesture: gesture)
        }
    }
    
    private func performPan(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            isDraggingPane = true
            initialDragHeight = bottomContainerHeightConstraint.constant
            lastFeedbackBreakpoint = currentBreakpoint
            
            startDisplayLink()
            
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.handle.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                self.handle.alpha = 0.8
            }
            
        case .changed:
            let newHeight = initialDragHeight - translation.y
            let clampedHeight = applyRubberBanding(to: newHeight, from: initialDragHeight)
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bottomContainerHeightConstraint.constant = clampedHeight
            layoutIfNeeded()
            CATransaction.commit()
            
            notifyPanEffectingViews()
            delegate?.splitPaneView(self, isDraggingWithTranslation: translation, velocity: velocity)
        case .ended, .cancelled, .failed:
            isDraggingPane = false
            stopDisplayLink()
            
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.handle.transform = .identity
                self.handle.alpha = 1.0
            }
            
            guard bounds.height > 0 else { return }
            
            let finalHeight = bottomContainerHeightConstraint.constant
            let currentRatio = finalHeight / bounds.height
            let totalDragDistance = initialDragHeight - finalHeight
            let exceededDragThreshold = abs(totalDragDistance) > configuration.dragThreshold
            let exceededVelocityThreshold = abs(velocity.y) > configuration.velocityThreshold
            var targetBreakpoint: SplitPaneBreakpoint
            
            if exceededDragThreshold || exceededVelocityThreshold {
                let movingDown = velocity.y > 0 || (velocity.y == 0 && totalDragDistance > 0)
                if movingDown {
                    targetBreakpoint = breakpoints.reversed().first { $0.ratio < currentRatio - 0.01 } ?? breakpoints.first ?? currentBreakpoint
                } else {
                    targetBreakpoint = breakpoints.first { $0.ratio > currentRatio + 0.01 } ?? breakpoints.last ?? currentBreakpoint
                }
            } else {
                targetBreakpoint = currentBreakpoint
            }
            
            transitionTo(breakpoint: targetBreakpoint)
            
        default:
            isDraggingPane = false
            stopDisplayLink()
            break
        }
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = panGesture.velocity(in: self)
        guard abs(velocity.y) > abs(velocity.x) else { return false }
        
        if let scrollView = gestureRecognizer.view as? UIScrollView {
            let topOffset = -scrollView.adjustedContentInset.top
            return scrollView.contentOffset.y <= topOffset && velocity.y > 0
        }
        
        // For content pan gesture, check if it's more vertical than horizontal
        // and if there's a scroll view, make sure it's disabled or at the top
        if gestureRecognizer == contentPanGesture {
            if let scrollView = bottomPaneContent?.dismissalHandlingScrollView,
               scrollView.isScrollEnabled {
                let location = panGesture.location(in: scrollView)
                if scrollView.point(inside: location, with: nil) {
                    let topOffset = -scrollView.adjustedContentInset.top
                    if scrollView.contentOffset.y > topOffset || velocity.y < 0 {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition with the dismissal scroll view
        if let scrollView = bottomPaneContent?.dismissalHandlingScrollView,
           (otherGestureRecognizer == scrollView.panGestureRecognizer ||
            gestureRecognizer.view == scrollView) {
            return true
        }
        
        // Allow simultaneous recognition with button tap gestures
        if otherGestureRecognizer is UITapGestureRecognizer {
            return true
        }
        
        // Don't allow simultaneous recognition with scroll view's pan gesture when content pan is active
        if gestureRecognizer == contentPanGesture,
           let scrollView = bottomPaneContent?.dismissalHandlingScrollView,
           otherGestureRecognizer == scrollView.panGestureRecognizer {
            let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: self) ?? .zero
            let topOffset = -scrollView.adjustedContentInset.top
            return scrollView.contentOffset.y <= topOffset && velocity.y > 0
        }
        
        // Don't interfere with other pan gestures (like swipe-to-delete in table views etc)
        if otherGestureRecognizer is UIPanGestureRecognizer && gestureRecognizer == contentPanGesture {
            return false
        }
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UITapGestureRecognizer && gestureRecognizer == contentPanGesture {
            return true
        }
        
        if gestureRecognizer == contentPanGesture,
           let scrollView = bottomPaneContent?.dismissalHandlingScrollView,
           scrollView.isScrollEnabled,
           otherGestureRecognizer == scrollView.panGestureRecognizer {
            return true
        }
        
        return false
    }
}


extension SplitPaneView: SplitPanePanEffectingView {
    public func splitPaneDidTransitionToBreakpoint(_ splitPane: SplitPaneView, breakpoint: SplitPaneBreakpoint) {
        //
    }
    
    public func splitPaneDidUpdateHeight(_ splitPane: SplitPaneView, height: CGFloat, progress: CGFloat, currentBreakpoint: SplitPaneBreakpoint?, nextBreakpoint: SplitPaneBreakpoint?) {
        //
    }
}

fileprivate extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
