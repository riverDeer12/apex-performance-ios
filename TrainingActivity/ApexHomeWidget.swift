//
//  ApexHomeWidget.swift
//  TrainingActivity
//

import SwiftUI
import WidgetKit

/// Home screen widget. Clients: the next appointment (date, time, "in 2 h",
/// coach) and the package ("5 / 12"). Coaches: the next appointment today
/// with its client and the requests waiting. Logged out: "Log in to Apex".
/// The app writes what it shows (HomeWidgetSnapshot); a tap opens the app
/// on the matching screen.
struct ApexHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HomeWidgetSnapshot.widgetKind, provider: HomeWidgetProvider()) { entry in
            HomeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .secondarySystemBackground)
                }
        }
        .configurationDisplayName(Text(verbatim: "Apex"))
        .description(Text(verbatim: HomeWidgetTexts.description))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct HomeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: HomeWidgetSnapshot?
}

struct HomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry {
        HomeWidgetEntry(date: .now, snapshot: HomeWidgetSnapshot(
            role: .client, languageCode: HomeWidgetTexts.language, title: "Apex", emptyText: "",
            appointmentStart: Date().addingTimeInterval(2 * 3600), personName: "—",
            packageText: "5 / 12", packageLabel: "", updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeWidgetEntry) -> Void) {
        completion(HomeWidgetEntry(date: .now, snapshot: HomeWidgetSnapshot.load()) )
    }

    /// Every 15 minutes, so "in 2 h" stays right; the app reloads it when
    /// its data changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeWidgetEntry>) -> Void) {
        let snapshot = HomeWidgetSnapshot.load()
        let now = Date()
        let entries = (0..<8).map { step in
            HomeWidgetEntry(date: now.addingTimeInterval(TimeInterval(step * 15 * 60)), snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(2 * 3600))))
    }
}

struct HomeWidgetView: View {
    let entry: HomeWidgetEntry

    @Environment(\.widgetFamily) private var family

    // The app's blue (apexAccent, #3A98E4).
    private static let accent = Color(red: 0x3A / 255, green: 0x98 / 255, blue: 0xE4 / 255)

    private var snapshot: HomeWidgetSnapshot? { entry.snapshot }

    private var locale: Locale {
        Locale(identifier: snapshot?.languageCode ?? HomeWidgetTexts.language)
    }

    /// Where a tap opens the app.
    private var url: URL? {
        switch snapshot?.role {
        case .client:
            if let id = snapshot?.appointmentId {
                return URL(string: "apexperformance://appointment/\(id.uuidString)")
            }
            return URL(string: "apexperformance://home")
        case .coach:
            if let id = snapshot?.appointmentId {
                return URL(string: "apexperformance://appointment/\(id.uuidString)")
            }
            return URL(string: "apexperformance://appointments")
        case .loggedOut, nil:
            return URL(string: "apexperformance://home")
        }
    }

    var body: some View {
        Group {
            if let snapshot, snapshot.role != .loggedOut {
                if family == .accessoryRectangular {
                    accessory(snapshot)
                } else {
                    content(snapshot)
                }
            } else {
                loggedOut
            }
        }
        .widgetURL(url)
    }

    private var loggedOut: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "APEX")
                .font(.caption.weight(.heavy))
                .tracking(3)
                .foregroundStyle(Self.accent)
            Spacer(minLength: 0)
            Label {
                Text(verbatim: snapshot?.emptyText ?? HomeWidgetTexts.logIn)
                    .font(.subheadline.weight(.semibold))
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Self.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func content(_ snapshot: HomeWidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: snapshot.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Self.accent)
                    .textCase(.uppercase)
                    .lineLimit(1)

                if let start = snapshot.appointmentStart, start > entry.date.addingTimeInterval(-3600) {
                    Text(verbatim: dayText(start))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(verbatim: start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let relative = relativeText(start) {
                        Text(verbatim: relative)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Self.accent)
                            .lineLimit(1)
                    }
                    if let person = snapshot.personName, !person.isEmpty {
                        Text(verbatim: person)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Spacer(minLength: 0)
                    Text(verbatim: snapshot.emptyText)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }

                if family == .systemSmall, let extra = extraText(snapshot) {
                    Spacer(minLength: 0)
                    Text(verbatim: extra)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if family == .systemMedium {
                extraColumn(snapshot)
            }
        }
    }

    // Package or requests beside the appointment.
    @ViewBuilder
    private func extraColumn(_ snapshot: HomeWidgetSnapshot) -> some View {
        let value = snapshot.role == .client ? snapshot.packageText : snapshot.pendingRequests.map { "\($0)" }
        let label = snapshot.role == .client ? snapshot.packageLabel : snapshot.pendingLabel
        if let value {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: label ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(verbatim: value)
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(snapshot.role == .coach && (snapshot.pendingRequests ?? 0) > 0
                                     ? Color.orange : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: 110, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // "Paket 5 / 12" or "Zahtjevi 3" under the appointment on the small widget.
    private func extraText(_ snapshot: HomeWidgetSnapshot) -> String? {
        if snapshot.role == .client, let package = snapshot.packageText {
            return "\(snapshot.packageLabel ?? "") \(package)"
        }
        if snapshot.role == .coach, let pending = snapshot.pendingRequests {
            return "\(snapshot.pendingLabel ?? "") \(pending)"
        }
        return nil
    }

    private func accessory(_ snapshot: HomeWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: snapshot.title)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            if let start = snapshot.appointmentStart, start > entry.date.addingTimeInterval(-3600) {
                Text(verbatim: "\(dayText(start)) \(start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))")
                    .lineLimit(1)
                Text(verbatim: [relativeText(start), snapshot.personName].compactMap { $0 }.joined(separator: " · "))
                    .lineLimit(1)
            } else {
                Text(verbatim: snapshot.emptyText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // "uto, 18. stu" in the app's language.
    private func dayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).locale(locale))
    }

    // "za 2 h" / "in 2 hr", nil once it started.
    private func relativeText(_ date: Date) -> String? {
        guard date > entry.date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: entry.date)
    }
}

/// Texts before the app wrote anything, in the iPhone's language.
enum HomeWidgetTexts {
    static var language: String {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return ["hr", "en", "it", "de"].contains(code) ? code : "en"
    }

    static var logIn: String {
        switch language {
        case "hr": "Prijavi se u Apex"
        case "it": "Accedi ad Apex"
        case "de": "Bei Apex anmelden"
        default: "Log in to Apex"
        }
    }

    static var description: String {
        switch language {
        case "hr": "Sljedeći termin i paket ili današnji termini i zahtjevi."
        case "it": "Il prossimo appuntamento e il pacchetto, o gli appuntamenti di oggi e le richieste."
        case "de": "Nächster Termin und Paket oder heutige Termine und Anfragen."
        default: "Your next appointment and package, or today's appointments and requests."
        }
    }
}
