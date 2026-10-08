//
//  UINavigationController+SwipeBack.swift
//  ApexPerformance
//

import UIKit

// Many screens hide the system back button and show their own, which turns
// off the swipe from the left edge to go back. Keeping the navigation
// controller as the gesture's delegate turns it back on everywhere.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    // Only when there is a screen to go back to, otherwise the
    // gesture would block touches on the first screen.
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer != interactivePopGestureRecognizer || viewControllers.count > 1
    }
}
