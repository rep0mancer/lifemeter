import SwiftUI
import LifeCore

@available(iOS 15.0, *)
struct AnswerField: View {
    let question: Question
    @Binding var textAnswer: String
    @Binding var boolAnswer: Bool

    var body: some View {
        switch question.answerType {
        case .bool:
            Toggle(question.text, isOn: $boolAnswer)
                .toggleStyle(SwitchToggleStyle())
        case .int:
            TextField(question.text, text: $textAnswer)
                .keyboardType(.numberPad)
        case .double:
            TextField(question.text, text: $textAnswer)
                .keyboardType(.decimalPad)
        case .string:
            TextField(question.text, text: $textAnswer)
        }
    }
}
