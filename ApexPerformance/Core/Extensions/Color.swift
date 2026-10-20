//
//  Color.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 24.12.2025..
//

import Foundation

import SwiftUI

extension Color {
    static let apexMainColor = Color("ApexMainColor")
    /// Main color as in light mode, for colors that must stay blue in dark
    /// mode too, like the worked muscles on the body map.
    static let apexMainBlue = Color(red: 0, green: 0x34 / 255, blue: 0xC4 / 255)
}
