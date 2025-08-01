import SwiftUI
import LifeCore

@available(iOS 15.0, *)
public struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingFlowViewModel()
    @State private var textAnswers: [String: String] = [:]
    @State private var boolAnswers: [String: Bool] = [:]

    public init() {}

    public var body: some View {
        let questions = viewModel.questionBank.questions
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                VStack(spacing: 24) {
                    AnswerField(
                        question: question,
                        textAnswer: Binding(
                            get: { textAnswers[question.id] ?? "" },
                            set: { textAnswers[question.id] = $0 }
                        ),
                        boolAnswer: Binding(
                            get: { boolAnswers[question.id] ?? false },
                            set: { boolAnswers[question.id] = $0 }
                        )
                    )
                    Button(index + 1 == questions.count ? "Finish" : "Next") {
                        let value: AnyCodable
                        switch question.answerType {
                        case .bool:
                            value = AnyCodable(boolAnswers[question.id] ?? false)
                        case .int:
                            value = AnyCodable(Int(textAnswers[question.id] ?? "") ?? 0)
                        case .double:
                            value = AnyCodable(Double(textAnswers[question.id] ?? "") ?? 0)
                        case .string:
                            value = AnyCodable(textAnswers[question.id] ?? "")
                        }
                        viewModel.answer(question: question, with: value)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle())
    }
}
