import AppIntents
import SwiftUI

@available(iOS 17.0, *)
public enum CatColour: String, CaseIterable, AppEnum {
    case orange
    case black
    case gray
    case white

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cat Colour")

    public static var caseDisplayRepresentations: [CatColour: DisplayRepresentation] = [
        .orange: DisplayRepresentation(title: "Orange"),
        .black: DisplayRepresentation(title: "Black"),
        .gray: DisplayRepresentation(title: "Gray"),
        .white: DisplayRepresentation(title: "White"),
    ]

    public var color: Color {
        switch self {
        case .orange: return .orange
        case .black: return .black
        case .gray: return .gray
        case .white: return .white
        }
    }
}

@available(iOS 17.0, *)
public struct CatColourIntent: AppIntent {
    public static var title: LocalizedStringResource = "Cat Colour"

    @Parameter(title: "Colour")
    public var colour: CatColour

    public init() {}

    public init(colour: CatColour) {
        self.colour = colour
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Cat Colour: \(\.$colour)")
    }

    public func perform() async throws -> some IntentResult {
        // Make sure to replace "YOUR_APP_GROUP_ID" with your actual App Group identifier.
        UserDefaults(suiteName: "YOUR_APP_GROUP_ID")?.set(colour.rawValue, forKey: "CatColour")
        return .result()
    }
}
