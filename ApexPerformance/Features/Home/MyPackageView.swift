//
//  MyPackageView.swift
//  ApexPerformance
//

import SwiftUI

/// Client's package worked out from credits and appointments: credits are
/// taken when an appointment is approved, so the credits left are still
/// to book, upcoming approved appointments are booked and past ones are done.
struct PackageSummary {
    // Approved appointments this month that are over.
    let done: Int
    // Upcoming approved appointments.
    let reserved: Int
    // Credits left to book.
    let available: Int

    init(client: UserProfile?, approvedAppointments: [Appointment], now: Date = .now) {
        done = approvedAppointments.filter {
            $0.endTime <= now && Calendar.current.isDate($0.startTime, equalTo: now, toGranularity: .month)
        }.count
        reserved = approvedAppointments.filter { $0.startTime > now }.count
        available = max(client?.credits ?? 0, 0)
    }

    var remaining: Int { reserved + available }
    var total: Int { done + remaining }
    var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }
    var isActive: Bool { remaining > 0 }
}

/// "Moj paket": trainings done, booked and left to book, with booking
/// and the upcoming appointments.
struct MyPackageView: View {
    let client: UserProfile?
    let approvedAppointments: [Appointment]
    let pendingAppointments: [Appointment]

    @EnvironmentObject private var authManager: AuthManager
    @State private var showCreateAppointment = false

    private var package: PackageSummary {
        PackageSummary(client: client, approvedAppointments: approvedAppointments)
    }

    // Upcoming appointments, approved and waiting for approval, soonest first.
    private var upcoming: [Appointment] {
        let now = Date()
        return (approvedAppointments + pendingAppointments)
            .filter { $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ApexScreenHeader(title: "my_package", showsWordmark: false)

                ApexPictureBackground(systemImage: "figure.strengthtraining.traditional")
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                summaryCard

                if !upcoming.isEmpty {
                    upcomingCard
                }

                Label("cancelation_terms_by_agreement", systemImage: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ApexTitleBar(subtitle: ClientPlan.title(for: client?.plan))
            }
        }
        .navigationDestination(isPresented: $showCreateAppointment) {
            CreateAppointmentView()
        }
    }

    private var summaryCard: some View {
        let package = package

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("package_trainings \(package.total)")
                    .apexSectionTitle()
                Spacer()
                if package.isActive {
                    Text("active_package")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.green.opacity(0.7), lineWidth: 1)
                        )
                }
            }

            HStack(spacing: 0) {
                stat(package.done, label: "done_this_month")
                Divider().overlay(Color.apexBorder)
                stat(package.reserved, label: "reserved")
                Divider().overlay(Color.apexBorder)
                stat(package.available, label: "to_book")
            }
            .frame(height: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.apexBorder, lineWidth: 1)
            )

            Text("remaining_includes_reserved \(package.remaining) \(package.reserved)")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            if authManager.hasPermission(permission: Permissions.canGetAppointments) {
                Button("book_appointment") {
                    showCreateAppointment = true
                }
                .buttonStyle(ApexPrimaryButtonStyle())
                .disabled(package.available == 0)
                .opacity(package.available == 0 ? 0.5 : 1)
            }
        }
        .padding(16)
        .apexCardBackground()
    }

    private func stat(_ value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: "\(value)")
                .font(.system(size: 22, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("upcoming_appointments")
                .apexSectionTitle()
                .padding(.bottom, 6)

            ForEach(upcoming) { appointment in
                Divider().overlay(Color.apexBorder)
                NavigationLink {
                    AppointmentDetailsView(appointment: appointment)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(verbatim: ClientHomeView.dateAndTime(appointment.startTime))
                            .font(.subheadline.weight(.semibold))
                        if appointment.status.name == BusinessStatus.pending.rawValue {
                            Text("pending")
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 2)
        .apexCardBackground()
    }
}
