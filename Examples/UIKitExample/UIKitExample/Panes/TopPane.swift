//
//  TopPane.swift
//  UIKitExample
//
//  Created by Joseph Smith on 13/07/2025.
//

import UIKit
import SplitPaneKit

/// This example shows you you can programatically adjust the splitPaneViews
/// Helpful for if you want an action to trigger opening or closing the pane
class TopContentView: SplitPaneContentView {
    private lazy var quarterButton  = UIButton.menuTile(title: "1/4", symbol: "square.split.bottomrightquarter.fill")
    private lazy var halfButton   = UIButton.menuTile(title: "1/2", symbol: "square.split.1x2.fill")
    private lazy var threeQuarterButton = UIButton.menuTile(title: "3/4", symbol: "square.split.bottomrightquarter.fill", rotateIcon: true)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.addArrangedSubview(quarterButton)
        stack.addArrangedSubview(halfButton)
        stack.addArrangedSubview(threeQuarterButton)
        stack.layer.cornerCurve = .continuous
        stack.layer.cornerRadius = 20
        stack.clipsToBounds = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
        
        quarterButton.addTarget(self, action: #selector(quarterTapped), for: .touchUpInside)
        halfButton.addTarget(self, action: #selector(halfTapped), for: .touchUpInside)
        threeQuarterButton.addTarget(self, action: #selector(threeQuartersTapped), for: .touchUpInside)
    }
    
    @objc private func quarterTapped() {
        splitPaneView?.transitionTo(breakpoint: .quarter)
    }
    
    @objc private func halfTapped() {
        splitPaneView?.transitionTo(breakpoint: .half)
    }
    
    @objc private func threeQuartersTapped() {
        splitPaneView?.transitionTo(breakpoint: .threeQuarters)
    }
}

/// Some private extension helpers just for looks
private extension UIImage {
    func rotate() -> UIImage {
        guard let cgImage = cgImage else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: 270 * (.pi / 180))
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

private extension UIButton {
  static func menuTile(
    title: String,
    symbol: String,
    iconColor: UIColor = .label,
    textColor: UIColor = .systemGray,
    rotateIcon: Bool = false
  ) -> UIButton {
      var cfg = UIButton.Configuration.plain()
      let symCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
      var image = UIImage(systemName: symbol, withConfiguration: symCfg)
      
      // Rotate the image if needed
      if rotateIcon, let originalImage = image {
          image = originalImage.withRenderingMode(.alwaysTemplate).rotate().withRenderingMode(.alwaysTemplate)
      }
      
      cfg.image = image
      cfg.imagePlacement = .top
      cfg.imagePadding = 16
      cfg.cornerStyle = .fixed
      cfg.imageColorTransformer = UIConfigurationColorTransformer { _ in iconColor }
      cfg.title = title.uppercased()
      cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var out = incoming
        out.font = .rounded(ofSize: 12, weight: .heavy)
        out.foregroundColor = textColor
        return out
      }
      let btn = UIButton(configuration: cfg)
      btn.backgroundColor = .tertiarySystemGroupedBackground
      btn.layer.cornerRadius = 4
      btn.layer.cornerCurve = .continuous
      btn.clipsToBounds = true
      btn.translatesAutoresizingMaskIntoConstraints = false
      let square = btn.heightAnchor.constraint(equalTo: btn.widthAnchor, multiplier: 0.9)
      square.priority = .defaultHigh
      square.isActive = true
      return btn
  }
}
