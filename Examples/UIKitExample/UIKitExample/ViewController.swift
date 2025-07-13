//
//  ViewController.swift
//  UIKitExample
//
//  Created by Joseph Smith on 12/07/2025.
//

import UIKit
import SplitPaneKit

class ViewController: UIViewController {
    private let splitPaneView: SplitPaneView
    
    
    init() {
        let topContentView = TopContentView()
        let bottomContentView = BottomContentView()
        
        var configuration = SplitPaneConfiguration()
        configuration.defaultBreakpoint = .quarter
        configuration.topPaneContent = topContentView
        configuration.bottomPaneContent = bottomContentView
        
        self.splitPaneView = SplitPaneView(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        splitPaneView.delegate = self
        view.addSubview(splitPaneView)
        splitPaneView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            splitPaneView.topAnchor.constraint(equalTo: view.topAnchor),
            splitPaneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitPaneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitPaneView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set breakpoints
        /// Note: you can also programatically go to different breakpoints that aren't defined here
        splitPaneView.setBreakpoints([
            .quarter,
            .half,
            .threeQuarters,
        ])
    }
}

// MARK: - SplitPaneViewDelegate
extension ViewController: SplitPaneViewDelegate {
    func splitPaneView(_ splitPaneView: SplitPaneView, didTransitionTo breakpoint: SplitPaneBreakpoint) {
        //
    }
    
    func splitPaneView(_ splitPaneView: SplitPaneView, isDraggingWithTranslation translation: CGPoint, velocity: CGPoint) {
        //
    }
}
