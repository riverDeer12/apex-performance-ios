//
//  ToastManager.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 07.01.2026..
//

import Foundation

import SwiftUI


@MainActor
final class ToastManager: ObservableObject {
    @Published var toast: (message: LocalizedStringKey, type: ToastType)?
    
    func show(_ message: LocalizedStringKey, type: ToastType, duration: Double = 5) {
        withAnimation {
            toast = (message, type)
        }
        
        Task {
            try? await Task.sleep(for: .seconds(duration))
            withAnimation {
                toast = nil
            }
        }
    }
}
