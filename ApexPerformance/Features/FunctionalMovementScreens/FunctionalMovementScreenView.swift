//
//  FunctionalMovementScreenView.swift
//  ApexPerformance
//

import SwiftUI

// Creates a new FMS for the client when `screen` is nil,
// otherwise shows the existing one and lets staff edit it.
struct FunctionalMovementScreenView: View {
    let clientId: UUID
    let screen: FunctionalMovementScreen?
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var deepSquat: String
    @State private var hurdleStep: String
    @State private var inLineLunge: String
    @State private var activeStraightLegRaise: String
    @State private var trunkStabilityPushUp: String
    @State private var rotaryStability: String
    @State private var shoulderMobility: String
    @State private var xTest: String
    @State private var descriptionText: String
    @State private var isSaving = false

    init(clientId: UUID, screen: FunctionalMovementScreen? = nil, onSaved: (() -> Void)? = nil) {
        self.clientId = clientId
        self.screen = screen
        self.onSaved = onSaved
        _deepSquat = State(initialValue: screen?.deepSquat ?? "")
        _hurdleStep = State(initialValue: screen?.hurdleStep ?? "")
        _inLineLunge = State(initialValue: screen?.inLineLunge ?? "")
        _activeStraightLegRaise = State(initialValue: screen?.activeStraightLegRaise ?? "")
        _trunkStabilityPushUp = State(initialValue: screen?.trunkStabilityPushUp ?? "")
        _rotaryStability = State(initialValue: screen?.rotaryStability ?? "")
        _shoulderMobility = State(initialValue: screen?.shoulderMobility ?? "")
        _xTest = State(initialValue: screen?.xTest ?? "")
        _descriptionText = State(initialValue: screen?.description ?? "")
    }

    private var isNew: Bool { screen == nil }

    // Same limits as the API.
    private static let xTestMaxLength = 50
    private static let descriptionMaxLength = 2000

    // API requires a result for every test, description is optional.
    private var isValid: Bool {
        [deepSquat, hurdleStep, inLineLunge, activeStraightLegRaise,
         trunkStabilityPushUp, rotaryStability, shoulderMobility, xTest]
            .allSatisfy { !trimmed($0).isEmpty }
            && trimmed(xTest).count <= Self.xTestMaxLength
            && trimmed(descriptionText).count <= Self.descriptionMaxLength
    }

    var body: some View {
        Form {
            if let screen {
                Section {
                    Text(DateFormatter.dateAndTimeWithDots.string(from: screen.createdAt))
                        .foregroundStyle(.secondary)
                }
            }

            testSection("deep_squat", text: $deepSquat)
            testSection("hurdle_step", text: $hurdleStep)
            testSection("in_line_lunge", text: $inLineLunge)
            testSection("active_straight_leg_raise", text: $activeStraightLegRaise)
            testSection("trunk_stability_push_up", text: $trunkStabilityPushUp)
            testSection("rotary_stability", text: $rotaryStability)
            testSection("shoulder_mobility", text: $shoulderMobility)

            Section {
                TextField("x_test", text: $xTest, axis: .vertical)
                    .lineLimit(1...3)
            } header: {
                Text("x_test")
            } footer: {
                if trimmed(xTest).count > Self.xTestMaxLength {
                    Text("fms_max_length_50")
                        .foregroundStyle(.red)
                }
            }

            Section(header: Text("description")) {
                TextField("description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...10)
            }
        }
        .navigationTitle(LocalizedStringKey(isNew ? "new_fms" : "fms"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .foregroundStyle(Color.apexMainColor)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
                .accessibilityLabel("save")
                .disabled(isSaving || !isValid)
            }
        }
    }

    private func testSection(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        Section(header: Text(title)) {
            TextField(title, text: text, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let request = FunctionalMovementScreenRequest(
            client: clientId,
            deepSquat: trimmed(deepSquat),
            hurdleStep: trimmed(hurdleStep),
            inLineLunge: trimmed(inLineLunge),
            activeStraightLegRaise: trimmed(activeStraightLegRaise),
            trunkStabilityPushUp: trimmed(trunkStabilityPushUp),
            rotaryStability: trimmed(rotaryStability),
            shoulderMobility: trimmed(shoulderMobility),
            xTest: trimmed(xTest),
            description: trimmed(descriptionText).isEmpty ? nil : trimmed(descriptionText)
        )

        var url = AppEnvironment.apiURL.appendingPathComponent("functional-movement-screens")
        if let screen {
            url.appendPathComponent(screen.id.uuidString)
        }

        do {
            // API answers with a status code only, so the body is not decoded.
            try await APIClient.shared.requestData(
                url,
                method: isNew ? .post : .put,
                body: JSONEncoder().encode(request)
            )
            toastManager.show(LocalizedStringKey(isNew ? "fms_created_successfully" : "fms_updated_successfully"), type: .success)
            onSaved?()
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview("New") {
    NavigationStack {
        FunctionalMovementScreenView(clientId: UUID())
            .environmentObject(ToastManager())
    }
}

#Preview("Existing") {
    NavigationStack {
        FunctionalMovementScreenView(
            clientId: UUID(),
            screen: FunctionalMovementScreen(
                id: UUID(),
                deepSquat: "2 - heels lift",
                hurdleStep: "3",
                inLineLunge: "2 - loss of balance on left side",
                activeStraightLegRaise: "3",
                trunkStabilityPushUp: "1",
                rotaryStability: "2",
                shoulderMobility: "2 - right side limited",
                xTest: "2",
                description: "Focus on hip mobility before the next assessment.",
                createdAt: .now,
                client: .init(id: UUID(), firstName: "Jane", lastName: "Doe")
            )
        )
        .environmentObject(ToastManager())
    }
}
