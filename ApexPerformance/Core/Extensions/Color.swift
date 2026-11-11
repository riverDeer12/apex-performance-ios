//
//  Color.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 24.12.2025..
//

import Foundation

import SwiftUI

extension Color {
    /// The app's one blue: sky blue #3A98E4, lighter #5CB5F5 in dark mode
    /// (same as ApexAccent). Blue text on it should be at least semibold.
    static let apexMainColor = Color("ApexMainColor")
    /// The blue as in light mode, for colors that must not change with the
    /// appearance, like the worked muscles on the body map.
    static let apexMainBlue = Color(red: 0x3A / 255, green: 0x98 / 255, blue: 0xE4 / 255)
}
