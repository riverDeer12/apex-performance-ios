//
//  HomeView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
            
        TabView{
            if(authManager.hasPermission(permission: Permissions.canGetAppointments)){
                AppointmentsView()
                    .tabItem {
                        Label("", systemImage: "calendar")
                    }
            }

            
            if(authManager.hasPermission(permission: Permissions.canGetWorkouts)){
                WorkoutsView()
                    .tabItem {
                        Label("", systemImage: "person.3")
                    }
            }
            
            if(!authManager.hasRole(role: "Client")){
                ClientsView()
                    .tabItem {
                        Label("", systemImage: "person.3")
                    }
            }
            
            UserProfileView()
                .tabItem {
                    Label("", systemImage: "person")
                }
        }
        .tint(.apexMainColor)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
}
