import Foundation

public struct LifeExpectancyCalculator {
    public init() {}

    public func calculate(for profile: UserProfile, now: Date = Date()) -> Double {
        let age = Calendar.current.dateComponents([.year], from: profile.birthDate, to: now).year ?? 0
        var expectancy = 80.0 // base
        expectancy -= Double(age)
        // iterate profile.answers and adjust expectancy… (placeholder switch)
        return max(expectancy, 0)
    }
}
