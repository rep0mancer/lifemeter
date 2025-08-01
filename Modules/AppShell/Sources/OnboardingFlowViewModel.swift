import SwiftUI
import LifeCore

@available(iOS 15.0, *)
public final class OnboardingFlowViewModel: ObservableObject {
    @Published public var currentIndex: Int = 0
    @ObservedObject public var questionBank = QuestionBank.shared
    private let lifeViewModel = LifeViewModel()

    public init() {}

    public func answer(question: Question, with value: AnyCodable) {
        lifeViewModel.answer(question: question.id, with: value)
        currentIndex += 1
    }
}
