import Foundation

/// How far off someone's time estimates run, learned from their own history.
struct EstimateCalibration: Equatable, Sendable {
    /// Completed tasks that had both an estimate and a real duration.
    var sampleCount: Int
    /// Median of actual ÷ estimated. Above 1 means things take longer than
    /// expected.
    var factor: Double

    var isReliable: Bool { sampleCount >= EstimateCalibrator.minimumSamples }

    static let unknown = EstimateCalibration(sampleCount: 0, factor: 1)

    /// Percentage points off, rounded to the nearest five — the data does not
    /// justify claiming more precision than that.
    var deviationPercent: Int {
        let raw = abs(factor - 1) * 100
        return Int((raw / 5).rounded() * 5)
    }

    var direction: Direction {
        if factor > EstimateCalibrator.accurateBand.upperBound { return .underestimates }
        if factor < EstimateCalibrator.accurateBand.lowerBound { return .overestimates }
        return .accurate
    }

    enum Direction: Sendable, Equatable {
        case underestimates
        case overestimates
        case accurate
    }

    /// An observation about the user's own history, phrased as one. Never advice.
    var summary: String? {
        guard isReliable else { return nil }
        switch direction {
        case .underestimates:
            return "Across \(sampleCount) tasks, things have taken about \(deviationPercent)% longer than you expected."
        case .overestimates:
            return "Across \(sampleCount) tasks, things have taken about \(deviationPercent)% less time than you expected."
        case .accurate:
            return "Across \(sampleCount) tasks, your estimates have been close to right."
        }
    }

    /// The short version, for a settings row or a chip.
    var shortLabel: String? {
        guard isReliable, direction != .accurate else { return nil }
        let word = direction == .underestimates ? "under" : "over"
        return "\(word) by ~\(deviationPercent)%"
    }
}

enum EstimateCalibrator {

    /// Below this the sample is too small to say anything, and saying something
    /// anyway would be the app inventing a pattern out of three data points.
    static let minimumSamples = 10

    /// Inside this band the estimates are called accurate rather than nitpicked.
    static let accurateBand: ClosedRange<Double> = 0.9...1.1

    /// Padding is clamped here so a wild history can never produce an absurd
    /// suggestion.
    static let paddingBounds: ClosedRange<Double> = 0.5...3.0

    /// Median rather than mean, deliberately.
    ///
    /// One task estimated at fifteen minutes that turned into a four-hour
    /// rabbit hole would drag a mean far enough to make every future suggestion
    /// useless. The median shrugs it off.
    static func calibrate(_ tasks: [FocusTask]) -> EstimateCalibration {
        let ratios = tasks.compactMap(ratio(for:)).sorted()

        guard !ratios.isEmpty else { return .unknown }

        return EstimateCalibration(sampleCount: ratios.count, factor: median(ratios))
    }

    /// Only counts tasks that were actually finished and have both numbers.
    static func ratio(for task: FocusTask) -> Double? {
        guard task.isCompleted,
              let estimate = task.estimateMinutes, estimate > 0,
              let actual = task.actualMinutes, actual > 0
        else { return nil }
        return Double(actual) / Double(estimate)
    }

    static func median(_ sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 1 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// What an estimate becomes once the user's own history is applied.
    /// Returns the original when there is not enough to go on.
    static func padded(_ minutes: Int, using calibration: EstimateCalibration) -> Int {
        guard calibration.isReliable, minutes > 0 else { return minutes }
        let clamped = min(max(calibration.factor, paddingBounds.lowerBound), paddingBounds.upperBound)
        return max(1, Int((Double(minutes) * clamped).rounded()))
    }
}

/// How one finished task compared with its estimate.
struct EstimateDelta: Equatable, Sendable {
    var estimateMinutes: Int
    var actualMinutes: Int

    var differenceMinutes: Int { actualMinutes - estimateMinutes }
    var ranOver: Bool { differenceMinutes > 0 }

    /// Plain arithmetic, no verdict attached. Being wrong about how long
    /// something takes is the condition, not a failing.
    var summary: String {
        let magnitude = abs(differenceMinutes)
        if magnitude == 0 {
            return "Estimated \(estimateMinutes) min, took exactly that."
        }
        let word = ranOver ? "over" : "under"
        return "Estimated \(estimateMinutes) min, took \(actualMinutes). \(magnitude) min \(word)."
    }

    init?(task: FocusTask) {
        guard let estimate = task.estimateMinutes, estimate > 0,
              let actual = task.actualMinutes, actual > 0
        else { return nil }
        estimateMinutes = estimate
        actualMinutes = actual
    }
}
