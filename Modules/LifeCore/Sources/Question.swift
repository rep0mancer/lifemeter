import Foundation

public enum AnswerType: String, Codable {
    case bool
    case int
    case double
    case string
}

public struct Question: Codable, Identifiable {
    public let id: String
    public let text: String
    public let answerType: AnswerType

    public init(id: String, text: String, answerType: AnswerType) {
        self.id = id
        self.text = text
        self.answerType = answerType
    }
}
