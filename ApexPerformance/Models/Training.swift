//
//  Training.swift
//  ApexPerformance
//

import Foundation

/// Training a coach prepared for a client (GET trainings). Clients get
/// their own trainings, coaches the trainings of their clients.
struct Training: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let date: Date
    let note: String?
    var isCompleted: Bool
    var completedAt: Date?
    let client: Person
    let exercises: [Exercise]
    // When the training really started and ended, marked by the coach.
    // Started and not completed is in progress, clients see it then.
    var startedAt: Date? = nil
    var endedAt: Date? = nil
    // Client's heart rate in between, from Apple Health on the client's iPhone.
    var heartRate: HeartRate? = nil

    /// Beats per minute.
    struct HeartRate: Codable, Hashable {
        let min: Int
        let max: Int
        let average: Int
    }

    /// Started by the coach, not completed yet.
    var isInProgress: Bool {
        !isCompleted && startedAt != nil
    }

    struct Person: Decodable, Hashable {
        let id: UUID
        let firstName: String?
        let lastName: String?
    }

    struct Exercise: Identifiable, Decodable, Hashable {
        let id: UUID
        let workoutId: UUID
        // Persisted JSON with the workout name translations.
        let workoutName: LocalizedText
        let order: Int
        let note: String?
        let sets: [ExerciseSet]
        // Done right after the previous exercise without rest (superset).
        var isSupersetWithPrevious = false
        // PaceType raw value of the workout: sets with a distance show this pace.
        var paceType: String? = nil
    }

    struct ExerciseSet: Identifiable, Decodable, Hashable {
        let id: UUID
        let order: Int
        let reps: String?
        let weight: Decimal?
        // Done right after the previous set with less weight (drop set).
        var isDropSet = false
        // How long the set lasted, for workouts done for a time (e.g. plank).
        var durationSeconds: Int? = nil
        // Distance covered, for workouts with a pace type (e.g. rowing 2000 m).
        var distanceMeters: Int? = nil
    }
}

extension Training.ExerciseSet {
    private enum CodingKeys: String, CodingKey {
        case id, order, reps, weight, isDropSet, durationSeconds, distanceMeters
    }

    // In an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        order = try container.decode(Int.self, forKey: .order)
        reps = try container.decodeIfPresent(String.self, forKey: .reps)
        weight = try container.decodeIfPresent(Decimal.self, forKey: .weight)
        isDropSet = try container.decodeIfPresent(Bool.self, forKey: .isDropSet) ?? false
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceMeters = try container.decodeIfPresent(Int.self, forKey: .distanceMeters)
    }

    /// Distance, duration, pace and reps of a set over a distance, e.g.
    /// "2 km · 7:30 · 1:52 /500 m" like the web; nil for a set without a distance.
    func distanceText(paceType: String?) -> String? {
        guard let distanceMeters, distanceMeters > 0 else { return nil }
        let duration = durationSeconds.flatMap { $0 > 0 ? SetDuration.text($0) : nil } ?? ""
        return [
            SetPace.distance(distanceMeters),
            duration,
            SetPace.pace(paceType, meters: distanceMeters, seconds: durationSeconds),
            reps?.trimmingCharacters(in: .whitespaces) ?? ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}

/// Duration of a set as minutes and seconds, e.g. "1:30" or "1:02:30".
enum SetDuration {
    static func text(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        let rest = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }
}

/// Distance and pace of sets over a distance, formatted like the web
/// (Croatian decimal comma): "800 m", "5,25 km", "1:52 /500 m", "24,5 km/h".
enum SetPace {
    /// Metres below a kilometre, otherwise kilometres: "800 m", "2 km", "5,25 km".
    static func distance(_ meters: Int) -> String {
        guard meters > 0 else { return "" }
        return meters < 1000
            ? "\(meters) m"
            : "\(number(Double(meters) / 1000, maximumFractionDigits: 2)) km"
    }

    /// Pace of a set from its distance and duration, "" when one is missing.
    static func pace(_ paceType: String?, meters: Int?, seconds: Int?) -> String {
        guard let meters, let seconds, meters > 0, seconds > 0 else { return "" }
        return speed(paceType, metersPerMinute: Double(meters) * 60 / Double(seconds))
    }

    /// Pace from a speed in metres per minute, as the fastest pace record is kept.
    static func speed(_ paceType: String?, metersPerMinute: Double) -> String {
        guard metersPerMinute > 0 else { return "" }

        if paceType == PaceType.kmh.rawValue {
            return "\(number(metersPerMinute * 60 / 1000, maximumFractionDigits: 1)) km/h"
        }

        let isPer500m = paceType == PaceType.per500m.rawValue
        let per: Double = isPer500m ? 500 : 1000
        let seconds = Int((per / metersPerMinute * 60).rounded())
        return "\(SetDuration.text(seconds)) /\(isPer500m ? "500 m" : "km")"
    }

    private static func number(_ value: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "hr_HR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

extension Array where Element == Training.ExerciseSet {
    /// Numbers of sets in order: 1, 2... for sets and nil for their drop
    /// sets, which belong to the set before them.
    var setNumbers: [Int?] {
        var number = 0
        return map { set in
            if set.isDropSet && number > 0 { return nil }
            number += 1
            return number
        }
    }

    /// Sets without their drop sets.
    var mainSetCount: Int {
        setNumbers.compactMap { $0 }.count
    }
}

extension Training.Exercise {
    private enum CodingKeys: String, CodingKey {
        case id, workoutId, workoutName, order, note, sets, isSupersetWithPrevious, paceType
    }

    // In an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(LocalizedText.self, forKey: .workoutName)
        order = try container.decode(Int.self, forKey: .order)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        sets = try container.decode([Training.ExerciseSet].self, forKey: .sets)
        isSupersetWithPrevious = try container.decodeIfPresent(Bool.self, forKey: .isSupersetWithPrevious) ?? false
        paceType = try container.decodeIfPresent(String.self, forKey: .paceType)
    }
}

enum SupersetLabels {
    /// Labels of exercises in order: "1.", "2." for single exercises and
    /// "3a", "3b" for exercises done together in a superset, like the web.
    /// `linked` tells for each exercise if it is in a superset with the previous one.
    static func labels(linked: [Bool]) -> [String] {
        let isLinked = linked.indices.map { $0 > 0 && linked[$0] }

        var numbers: [Int] = []
        var number = 0
        for index in linked.indices {
            if !isLinked[index] { number += 1 }
            numbers.append(number)
        }

        return linked.indices.map { index -> String in
            let startsSuperset = index + 1 < linked.count && isLinked[index + 1]
            guard isLinked[index] || startsSuperset else { return "\(numbers[index])." }

            // Letter by position in the superset: a, b, c...
            var first = index
            while isLinked[first] { first -= 1 }
            let letter = Character(UnicodeScalar(UInt8(97 + min(index - first, 25))))
            return "\(numbers[index])\(letter)"
        }
    }
}

extension Training {
    /// All trainings the logged user can see, newest first.
    @MainActor
    static func loadAll() async throws -> [Training] {
        let url = AppEnvironment.apiURL.appendingPathComponent("trainings")
        let trainings: [Training] = try await APIClient.shared.request(url)
        return trainings.sorted { $0.date > $1.date }
    }

    /// Completed trainings the logged user can see, newest first.
    @MainActor
    static func loadCompleted() async throws -> [Training] {
        try await loadAll().filter(\.isCompleted)
    }

    /// Client's trainings: in progress (started by the coach) and completed.
    @MainActor
    static func loadStartedOrCompleted() async throws -> [Training] {
        try await loadAll().filter { $0.isCompleted || $0.isInProgress }
    }

    /// Creates a training, or updates it when an id is given (staff only).
    @MainActor
    static func save(_ request: SaveTrainingRequest, id: UUID? = nil) async throws -> Training {
        var url = AppEnvironment.apiURL.appendingPathComponent("trainings")
        if let id {
            url = url.appendingPathComponent(id.uuidString)
        }
        return try await APIClient.shared.request(
            url,
            method: id == nil ? .post : .put,
            body: JSONEncoder().encode(request)
        )
    }
}

extension Training {
    /// Marks the training as completed or planned (staff only).
    /// Returns the training with the new state.
    @MainActor
    func settingCompletion(_ isCompleted: Bool) async throws -> Training {
        struct Request: Encodable { let isCompleted: Bool }
        struct Response: Decodable {
            let isCompleted: Bool
            let completedAt: Date?
        }

        let url = AppEnvironment.apiURL
            .appendingPathComponent("trainings")
            .appendingPathComponent(id.uuidString)
            .appendingPathComponent("completion")
        let response: Response = try await APIClient.shared.request(
            url,
            method: .put,
            body: JSONEncoder().encode(Request(isCompleted: isCompleted))
        )

        return Training(
            id: id, name: name, date: date, note: note,
            isCompleted: response.isCompleted, completedAt: response.completedAt,
            client: client, exercises: exercises
        )
    }

    /// Deletes the training (soft delete on the API, staff only).
    @MainActor
    static func delete(id: UUID) async throws {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("trainings")
            .appendingPathComponent(id.uuidString)
        try await APIClient.shared.requestData(url, method: .delete)
    }
}

/// Body of POST trainings and PUT trainings/{id}.
struct SaveTrainingRequest: Encodable {
    let client: UUID
    let name: String
    // ISO 8601, as the API expects a DateTimeOffset.
    let date: String
    let note: String?
    let isCompleted: Bool
    let exercises: [Exercise]
    // Push notification to the client. The API sends it for a new
    // training and not for an edited one when this is nil.
    var notifyClient: Bool? = nil

    struct Exercise: Encodable {
        let workout: UUID
        let note: String?
        let sets: [ExerciseSet]
        let isSupersetWithPrevious: Bool
    }

    struct ExerciseSet: Encodable {
        let reps: String?
        let weight: Decimal?
        var isDropSet = false
        var durationSeconds: Int? = nil
        var distanceMeters: Int? = nil
    }
}
