import Combine
import LifeCore

@MainActor
final class LifeViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile
    @Published private(set) var expectancy: Double = 0
    private let calc = LifeExpectancyCalculator()

    init() {
        profile = PersistenceService.loadProfile() ?? .init(birthDate: Date(), gender: .other)
        recalc()
    }

    func answer(question id: String, with value: AnyCodable) {
        profile.answers[id] = value
        persist()
    }

    func setBirth(date: Date) {
        profile.birthDate = date
        persist()
    }

    func setGender(_ g: Gender) {
        profile.gender = g
        persist()
    }

    private func persist() {
        PersistenceService.save(profile)
        recalc()
    }

    private func recalc() {
        expectancy = calc.calculate(for: profile)
    }
}
