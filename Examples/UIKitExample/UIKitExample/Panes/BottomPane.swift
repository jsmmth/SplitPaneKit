//
//  BottomPane.swift
//  UIKitExample
//
//  Created by Joseph Smith on 13/07/2025.
//

import UIKit
import SplitPaneKit

/// This example shows the bottom pane
/// It also shows how you can animate an element based on the drag translation
/// If you had other components within this you could animated directly from this view or simply call addPanEffectingView for the view to get its own delegate methods
class BottomContentView: SplitPaneContentView {
    /// Optional override if you have a containing scrollView that you still want to handle panning once scrolling past the top
    /// You may want to disable scroll during "closed" state.
    // override var dismissalHandlingScrollView: UIScrollView? {
        // return scrollView
    // }
    
    private let closeButton = UIButton.navButton(title: "Close")
    private let animatedSquare: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(animatedSquare)
        addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            animatedSquare.centerXAnchor.constraint(equalTo: centerXAnchor),
            animatedSquare.centerYAnchor.constraint(equalTo: centerYAnchor),
            animatedSquare.heightAnchor.constraint(equalToConstant: 150),
            animatedSquare.widthAnchor.constraint(equalToConstant: 150)
        ])
        
        // Set initial
        animatedSquare.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        closeButton.alpha = 0
        closeButton.transform = CGAffineTransform(translationX: 0, y: -20)
        
        // btn target
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }
    
    @objc private func closeTapped() {
        splitPaneView?.transitionTo(breakpoint: .quarter)
    }
}

// MARK: - SplitPanePanEffectingView
extension BottomContentView: SplitPanePanEffectingView {
    func splitPaneDidTransitionToBreakpoint(_ splitPane: SplitPaneView, breakpoint: SplitPaneBreakpoint) {
        if breakpoint == .threeQuarters {
            UIView.animate(withDuration: 0.2, animations: {
                self.closeButton.alpha = 1
                self.closeButton.transform = CGAffineTransform(translationX: 0, y: 0)
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.closeButton.alpha = 0
                self.closeButton.transform = CGAffineTransform(translationX: 0, y: -20)
            })
        }
    }
    
    func splitPaneDidUpdateHeight(_ splitPane: SplitPaneView, height: CGFloat, progress: CGFloat, currentBreakpoint: SplitPaneBreakpoint?, nextBreakpoint: SplitPaneBreakpoint?) {
        // Calculate overall progress from quarter (0.25) to three quarters (0.75)
        // This gives us a 0-1 range across all our breakpoints
        let minRatio: CGFloat = 0.25
        let maxRatio: CGFloat = 0.75
        let currentRatio = splitPane.bounds.height > 0 ? height / splitPane.bounds.height : 0
        
        let overallProgress = (currentRatio - minRatio) / (maxRatio - minRatio)
        let clampedProgress = min(max(overallProgress, 0), 1)
        
        // Scale from 0.2 to 1.0 based on overall progress
        let scale = 0.2 + (0.8 * clampedProgress)
        animatedSquare.transform = CGAffineTransform(scaleX: scale, y: scale)
        
        // Also animate color
        let hue = clampedProgress * 0.3 // From blue to green
        animatedSquare.backgroundColor = UIColor(hue: 0.6 - hue, saturation: 0.8, brightness: 0.8, alpha: 1.0)
        
        // Handle close button opacity
        // We want it to fade in as we approach three quarters (0.75)
        // Let's start fading in from 0.6 ratio
        let closeButtonFadeStart: CGFloat = 0.6
        let closeButtonFadeEnd: CGFloat = 0.75
        
        if currentRatio >= closeButtonFadeEnd {
            // Fully visible at three quarters and above
            closeButton.alpha = 1
            closeButton.transform = CGAffineTransform(translationX: 0, y: 0)
        } else if currentRatio <= closeButtonFadeStart {
            // Fully hidden below fade start
            closeButton.alpha = 0
            closeButton.transform = CGAffineTransform(translationX: 0, y: -20)
        } else {
            // Fade in between start and end
            let fadeProgress = (currentRatio - closeButtonFadeStart) / (closeButtonFadeEnd - closeButtonFadeStart)
            let translateProgress = -20 + (20 * fadeProgress)
            closeButton.alpha = fadeProgress
            closeButton.transform = CGAffineTransform(translationX: 0, y: translateProgress)
        }
    }
}

private extension UIButton {
  static func navButton(
    title: String,
    textColor: UIColor = .label
  ) -> UIButton {
      var cfg = UIButton.Configuration.plain()
      cfg.title = title.uppercased()
      cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var out = incoming
        out.font = .rounded(ofSize: 12, weight: .heavy)
        out.foregroundColor = textColor
        return out
      }
      cfg.contentInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
      let btn = UIButton(configuration: cfg)
      btn.backgroundColor = .tertiarySystemGroupedBackground
      btn.layer.cornerRadius = 12
      btn.layer.cornerCurve = .continuous
      btn.clipsToBounds = true
      btn.translatesAutoresizingMaskIntoConstraints = false
      return btn
  }
}
