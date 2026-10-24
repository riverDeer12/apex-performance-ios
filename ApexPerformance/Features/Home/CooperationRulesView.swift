//
//  CooperationRulesView.swift
//  ApexPerformance
//

import SwiftUI

/// Cooperation rules for individual trainings (GET rules). Clients on
/// private coaching accept them before using the app; a new version has
/// to be accepted again.
struct CooperationRules: Decodable, Identifiable, Equatable {
    let document: String
    // Version to accept, sent back when accepting.
    let version: String
    // PDF of the rules.
    let documentUrl: String
    let isRequired: Bool
    // The current version is accepted.
    let isAccepted: Bool
    let acceptedVersion: String?
    let acceptedAt: Date?

    var id: String { version }

    var needsAcceptance: Bool { isRequired && !isAccepted }

    // ErrorCodes.NotValid on the API: the rules changed since they were loaded.
    static let outdatedVersionErrorCode = "1001"

    private static var url: URL {
        AppEnvironment.apiURL.appendingPathComponent("rules")
    }

    @MainActor
    static func load() async throws -> CooperationRules {
        try await APIClient.shared.request(url)
    }

    @MainActor
    static func accept(version: String, guardianName: String?, independentTravelApproved: Bool) async throws
        -> CooperationRules {
        struct Request: Encodable {
            let version: String
            let guardianName: String?
            let independentTravelApproved: Bool
        }
        return try await APIClient.shared.request(
            url.appendingPathComponent("accept"),
            method: .post,
            body: JSONEncoder().encode(Request(
                version: version,
                guardianName: guardianName,
                independentTravelApproved: independentTravelApproved
            ))
        )
    }
}

/// Popup over the app that a client who has to accept the rules can't
/// close: they accept them or log out.
struct CooperationRulesView: View {
    let rules: CooperationRules
    var onAccepted: (CooperationRules) -> Void
    var onLogout: () -> Void

    @EnvironmentObject private var toastManager: ToastManager

    @State private var current: CooperationRules
    @State private var hasReadRules = false
    // Accepting as a parent or guardian of a minor client.
    @State private var isGuardian = false
    @State private var guardianName = ""
    @State private var approvesIndependentTravel = false
    @State private var isAccepting = false

    init(rules: CooperationRules, onAccepted: @escaping (CooperationRules) -> Void, onLogout: @escaping () -> Void) {
        self.rules = rules
        self.onAccepted = onAccepted
        self.onLogout = onLogout
        _current = State(initialValue: rules)
    }

    private var trimmedGuardianName: String {
        guardianName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAccept: Bool {
        hasReadRules && (!isGuardian || !trimmedGuardianName.isEmpty) && !isAccepting
    }

    var body: some View {
        ZStack {
            // Covers the app, nothing behind can be used.
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            // As tall as its content, scrolling when the screen is smaller.
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card }
            }
            .background(Color.apexBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 520)
            .padding(20)
        }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("rules_title")
                .font(.headline)
                .frame(maxWidth: .infinity)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.apexMainColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("rules_message")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let url = URL(string: current.documentUrl) {
                Link(destination: url) {
                    Label("rules_open_document", systemImage: "doc.richtext")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.apexMainColor.opacity(0.1))
                        )
                }
                .foregroundStyle(Color.apexMainColor)
            }

            checkbox(isOn: $hasReadRules, title: Text("rules_checkbox \(current.version)"))
                .accessibilityIdentifier("rules-checkbox")

            VStack(alignment: .leading, spacing: 12) {
                checkbox(isOn: $isGuardian.animation(), title: Text("rules_guardian"))
                if isGuardian {
                    TextField("rules_guardian_name", text: $guardianName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                    checkbox(isOn: $approvesIndependentTravel, title: Text("rules_independent_travel"))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.apexBorder, lineWidth: 1)
            )

            Button {
                Task { await accept() }
            } label: {
                if isAccepting {
                    ProgressView().tint(.white)
                } else {
                    Text("rules_accept")
                }
            }
            .buttonStyle(ApexPrimaryButtonStyle(systemImage: "checkmark"))
            .accessibilityIdentifier("rules-accept")
            .disabled(!canAccept)
            .opacity(canAccept ? 1 : 0.5)

            Button(role: .destructive) {
                onLogout()
            } label: {
                Text("logout")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(20)
    }

    private func checkbox(isOn: Binding<Bool>, title: Text) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isOn.wrappedValue ? Color.apexMainColor : Color.secondary)
                title
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    @MainActor
    private func accept() async {
        isAccepting = true
        defer { isAccepting = false }

        do {
            let accepted = try await CooperationRules.accept(
                version: current.version,
                guardianName: isGuardian ? trimmedGuardianName : nil,
                independentTravelApproved: isGuardian && approvesIndependentTravel
            )
            onAccepted(accepted)
        } catch ApiError.validation(let response)
                    where response.errors?["generalErrors"]?.contains(CooperationRules.outdatedVersionErrorCode) == true {
            // The rules changed in the meantime: show the new version.
            if let reloaded = try? await CooperationRules.load() {
                current = reloaded
                hasReadRules = false
            }
            toastManager.show("rules_new_version", type: .error)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Accepted rules in the client's profile: version, date and the PDF.
struct CooperationRulesRow: View {
    @State private var rules: CooperationRules?

    var body: some View {
        Group {
            if let rules, let acceptedVersion = rules.acceptedVersion, let url = URL(string: rules.documentUrl) {
                Divider().padding(.leading, 52)
                Link(destination: url) {
                    SettingsRowView(
                        icon: "doc.text",
                        iconTint: Color.apexMainColor,
                        title: Text("rules_title"),
                        subtitle: Text("rules_accepted_version \(acceptedVersion)")
                            + Text(verbatim: rules.acceptedAt.map { " · " + DateFormatter.dateWithDots.string(from: $0) } ?? ""),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            rules = try? await CooperationRules.load()
        }
    }
}
