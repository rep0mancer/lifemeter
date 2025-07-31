import Foundation

public enum Gender: String, Codable {
    case male, female, other
}

public struct UserProfile: Codable, Hashable {
    public var birthDate: Date
    public var gender: Gender
    public var answers: [String: AnyCodable]

    public init(birthDate: Date, gender: Gender, answers: [String: AnyCodable] = [:]) {
        self.birthDate = birthDate
        self.gender = gender
        self.answers = answers
    }

    public static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.birthDate == rhs.birthDate && lhs.gender == rhs.gender
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(birthDate)
        hasher.combine(gender)
    }
}
