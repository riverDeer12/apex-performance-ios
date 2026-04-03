//
//  ToastType.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 05.01.2026..
//

import Foundation

import SwiftUI

enum ToastType {
    case success
    case warning
    case error
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .info:
            return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .success: return "success"
        case .warning: return "warning"
        case .error: return "error"
        case .info: return "info"
        }
    }
}
