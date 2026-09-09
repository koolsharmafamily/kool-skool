import Foundation
import Testing
@testable import KoolSkool

@Suite("Estimate calibration")
struct EstimateCalibratorTests {

    /// A finished task with both numbers on it.
    private func task(estimate: Int?, actual: Int?, completed: Bool = true) -> FocusTask {
        var task = FocusTask()
        task.title = "Something"
        task.estimateMinutes = estimate
        task.actualMinutes = actual
        task.completedAt = completed ? Date() : nil
        return task
    }

    /// `count` tasks that each took `ratio` times as long as estimated.
    private func tasks(count: Int, ratio: Double, estimate: Int = 60) -> [FocusTask] {
        (0..<count).map { _ in
            task(estimate: estimate, actual: Int((Double(estimate) * ratio).rounded()))
        }
    }

    // MARK: Sample gathering

    @Test("Nothing to go on reports nothing")
    func emptyHistory() {
        let calibration = EstimateCalibrator.calibrate([])
        #expect(calibration == .unknown)
        #expect(calibration.isReliable == false)
        #expect(calibration.summary == nil)
    }

    @Test("Unfinished tasks are not evidence")
    func incompleteTasksAreIgnored() {
        let sample = (0..<12).map { _ in task(estimate: 60, actual: 90, completed: false) }
        #expect(EstimateCalibrator.calibrate(sample).sampleCount == 0)
    }

    @Test("Tasks missing either number are skipped")
    func partialTasksAreSkipped() {
        let sample = [
            task(estimate: nil, actual: 90),
            task(estimate: 60, actual: nil),
            task(estimate: 0, actual: 90),
            task(estimate: 60, actual: 0),
            task(estimate: 60, actual: 90),
        ]
        #expect(EstimateCalibrator.calibrate(sample).sampleCount == 1)
    }

    @Test("Below the threshold the app says nothing at all")
    func staysQuietUntilItHasEnough() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 9, ratio: 2))

        // Nine tasks is a hunch, not a pattern. Inventing one out of it would
        // be the app making things up about the user.
        #expect(calibration.sampleCount == 9)
        #expect(calibration.isReliable == false)
        #expect(calibration.summary == nil)
        #expect(calibration.shortLabel == nil)
    }

    @Test("At the threshold it starts talking")
    func speaksUpAtTen() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 10, ratio: 1.6))
        #expect(calibration.isReliable)
        #expect(calibration.summary != nil)
    }

    // MARK: The factor

    @Test("Consistent underestimating is measured as such")
    func underestimating() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 1.6))

        #expect(calibration.direction == .underestimates)
        #expect(calibration.deviationPercent == 60)
        #expect(calibration.shortLabel == "under by ~60%")
    }

    @Test("Consistent overestimating is measured as such")
    func overestimating() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 0.75))

        #expect(calibration.direction == .overestimates)
        #expect(calibration.deviationPercent == 25)
        #expect(calibration.shortLabel == "over by ~25%")
    }

    @Test("Close enough is called close enough")
    func accurateBand() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 1.05))

        #expect(calibration.direction == .accurate)
        // No nagging label for someone who is already getting it right.
        #expect(calibration.shortLabel == nil)
        #expect(calibration.summary?.contains("close to right") == true)
    }

    @Test("One catastrophic rabbit hole does not poison the figure")
    func medianResistsOutliers() {
        // Eleven tasks that ran 20% over, plus one that took forty times the
        // estimate. A mean would land near 4x and make every suggestion useless.
        var sample = tasks(count: 11, ratio: 1.2)
        sample.append(task(estimate: 15, actual: 600))

        let calibration = EstimateCalibrator.calibrate(sample)
        #expect(calibration.factor < 1.3)
        #expect(calibration.direction == .underestimates)
    }

    @Test("The median of an even sample splits the middle two")
    func evenSampleMedian() {
        #expect(EstimateCalibrator.median([1, 2, 3, 4]) == 2.5)
        #expect(EstimateCalibrator.median([2]) == 2)
        #expect(EstimateCalibrator.median([]) == 1)
    }

    // MARK: Padding

    @Test("Padding does nothing until the figure is trustworthy")
    func paddingWaitsForEvidence() {
        let thin = EstimateCalibrator.calibrate(tasks(count: 4, ratio: 2))
        #expect(EstimateCalibrator.padded(30, using: thin) == 30)
    }

    @Test("Padding applies the learned factor")
    func paddingApplies() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 1.5))
        #expect(EstimateCalibrator.padded(30, using: calibration) == 45)
        #expect(EstimateCalibrator.padded(60, using: calibration) == 90)
    }

    @Test("Padding shrinks an estimate for someone who overestimates")
    func paddingCanShrink() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 0.5))
        #expect(EstimateCalibrator.padded(60, using: calibration) == 30)
    }

    @Test("A wild history cannot produce an absurd suggestion")
    func paddingIsClamped() {
        let extreme = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 20))
        // Clamped at 3x rather than suggesting twenty hours for a one-hour task.
        #expect(EstimateCalibrator.padded(60, using: extreme) == 180)

        let tiny = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 0.05))
        #expect(EstimateCalibrator.padded(60, using: tiny) == 30)
    }

    @Test("Padding never produces zero")
    func paddingHasAFloor() {
        let calibration = EstimateCalibrator.calibrate(tasks(count: 12, ratio: 0.5))
        #expect(EstimateCalibrator.padded(1, using: calibration) >= 1)
        #expect(EstimateCalibrator.padded(0, using: calibration) == 0)
    }

    // MARK: One task's delta

    @Test("A finished task reports its own delta")
    func deltaForOneTask() throws {
        let over = try #require(EstimateDelta(task: task(estimate: 60, actual: 85)))
        #expect(over.differenceMinutes == 25)
        #expect(over.ranOver)
        #expect(over.summary == "Estimated 60 min, took 85. 25 min over.")

        let under = try #require(EstimateDelta(task: task(estimate: 60, actual: 40)))
        #expect(under.ranOver == false)
        #expect(under.summary == "Estimated 60 min, took 40. 20 min under.")

        let exact = try #require(EstimateDelta(task: task(estimate: 60, actual: 60)))
        #expect(exact.differenceMinutes == 0)
        #expect(exact.summary == "Estimated 60 min, took exactly that.")
    }

    @Test("A task without both numbers has no delta to report")
    func noDeltaWithoutBothNumbers() {
        #expect(EstimateDelta(task: task(estimate: nil, actual: 40)) == nil)
        #expect(EstimateDelta(task: task(estimate: 40, actual: nil)) == nil)
    }
}
