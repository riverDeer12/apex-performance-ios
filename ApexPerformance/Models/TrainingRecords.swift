//
//  TrainingRecords.swift
//  ApexPerformance
//

import Foundation

/// Weight records worked out on the device from the client's trainings
/// the app already loaded: the heaviest set of an exercise that isn't a
/// drop set.
enum TrainingRecords {

    /// Set of a training heavier than any earlier set of the same exercise.
    struct NewRecord: Identifiable, Hashable {
        let setId: UUID
        let workoutId: UUID
        let name: String
        let weight: Decimal
        let reps: String?

        var id: UUID { setId }

        // "Bench Press 72,5 kg"
        var text: String {
            "\(name) \(PersonalRecordFormat.kilograms(weight))"
        }
    }

    /// Best weight of one exercise and when it was first lifted.
    struct Best: Identifiable, Hashable {
        let workoutId: UUID
        let name: String
        let weight: Decimal
        let reps: String?
        let date: Date

        var id: UUID { workoutId }
    }

    /// Trainings that count as done: completed or started by the coach.
    private static func isDone(_ training: Training) -> Bool {
        training.isCompleted || training.startedAt != nil
    }

    private static func moment(_ training: Training) -> Date {
        training.startedAt ?? training.date
    }

    /// Sets of the training that beat every earlier set of their exercise.
    /// An exercise done for the first time is no record yet.
    static func newRecords(in training: Training, history: [Training]) -> [NewRecord] {
        let start = moment(training)
        var best: [UUID: Decimal] = [:]
        for earlier in history where earlier.client.id == training.client.id && earlier.id != training.id
            && isDone(earlier) && moment(earlier) < start {
            for exercise in earlier.exercises {
                for set in exercise.sets where !set.isDropSet {
                    guard let weight = set.weight, weight > 0 else { continue }
                    best[exercise.workoutId] = max(best[exercise.workoutId] ?? 0, weight)
                }
            }
        }

        var records: [NewRecord] = []
        for exercise in training.exercises.sorted(by: { $0.order < $1.order }) {
            guard let previous = best[exercise.workoutId] else { continue }
            let sets = exercise.sets.sorted { $0.order < $1.order }.filter { !$0.isDropSet }
            // The first of the heaviest sets above the earlier best.
            var top: Training.ExerciseSet?
            for set in sets {
                guard let weight = set.weight, weight > previous else { continue }
                if top == nil || weight > (top?.weight ?? 0) { top = set }
            }
            guard let top, let weight = top.weight else { continue }
            records.append(NewRecord(setId: top.id, workoutId: exercise.workoutId,
                                     name: exercise.workoutName.localized, weight: weight, reps: top.reps))
            // The same exercise again later in the training needs more.
            best[exercise.workoutId] = weight
        }
        return records
    }

    /// Best weight of every exercise in the trainings, the latest records first.
    static func bests(in trainings: [Training]) -> [Best] {
        var bests: [UUID: Best] = [:]
        for training in trainings.filter(isDone).sorted(by: { moment($0) < moment($1) }) {
            for exercise in training.exercises {
                for set in exercise.sets.sorted(by: { $0.order < $1.order }) where !set.isDropSet {
                    guard let weight = set.weight, weight > 0 else { continue }
                    if let current = bests[exercise.workoutId], current.weight >= weight { continue }
                    bests[exercise.workoutId] = Best(workoutId: exercise.workoutId,
                                                     name: exercise.workoutName.localized,
                                                     weight: weight, reps: set.reps, date: training.date)
                }
            }
        }
        return bests.values.sorted { $0.date == $1.date ? $0.name < $1.name : $0.date > $1.date }
    }

    // MARK: - Celebration

    private static let celebratedKey = "celebratedRecordTrainings"

    /// The client sees the new records of a training once, the first time
    /// it is opened.
    static func shouldCelebrate(_ trainingId: UUID) -> Bool {
        let celebrated = UserDefaults.standard.stringArray(forKey: celebratedKey) ?? []
        return !celebrated.contains(trainingId.uuidString)
    }

    static func markCelebrated(_ trainingId: UUID) {
        var celebrated = UserDefaults.standard.stringArray(forKey: celebratedKey) ?? []
        guard !celebrated.contains(trainingId.uuidString) else { return }
        celebrated.append(trainingId.uuidString)
        // Only the latest ones matter.
        UserDefaults.standard.set(Array(celebrated.suffix(200)), forKey: celebratedKey)
    }
}
