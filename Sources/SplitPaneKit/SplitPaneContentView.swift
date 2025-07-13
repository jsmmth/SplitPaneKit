//
//  SplitPaneContentView.swift
//  
//
//  Created by Joseph Smith on 13/07/2025.
//

import UIKit

/// Base class for content views that belong to a split pane
@MainActor
open class SplitPaneContentView: UIView {
    /// The split pane view this content belongs to (set automatically)
    public internal(set) weak var splitPaneView: SplitPaneView?
    
    /// Override to provide a scroll view for dismissal handling
    open var dismissalHandlingScrollView: UIScrollView? {
        return nil
    }
}
