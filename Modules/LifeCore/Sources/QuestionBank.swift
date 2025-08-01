import Combine
import Foundation

// MARK: - Question Bank

public final class QuestionBank: ObservableObject {
    public static let shared = QuestionBank()

    @Published public private(set) var questions: [Question] = []

    private var loaded = false

    private init() {
        load()
    }

    // MARK: - Loading

    private func load() {
        guard !loaded else { return }
        loaded = true

        if let url = Bundle.main.url(forResource: "questions", withExtension: "json", subdirectory: "Assets/Questions"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Question].self, from: data) {
            questions = decoded
        }
    }
}
