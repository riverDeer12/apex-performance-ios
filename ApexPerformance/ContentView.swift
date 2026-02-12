//
//  ContentView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 15.12.2025..
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
            
        if authManager.isAuthenticated {
            HomeView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
