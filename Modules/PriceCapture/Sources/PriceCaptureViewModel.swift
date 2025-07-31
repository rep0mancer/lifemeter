import CalcCore
import Combine
import Foundation
import HistoryStore
import UIKit
import Vision

// MARK: - Price Capture ViewModel

@available(iOS 15.0, *)
public class PriceCaptureViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var priceInput: String = ""
    @Published public var selectedCurrency: String = ""
    @Published public var showDocumentScanner: Bool = false
    @Published public var showImagePicker: Bool = false
    @Published public var showCurrencyPicker: Bool = false
    @Published public var isProcessingOCR: Bool = false
    @Published public var ocrError: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    private var currentImage: UIImage?

    // MARK: - Computed Properties

    public var isValidPrice: Bool {
        guard let price = Double(priceInput.replacingOccurrences(of: ",", with: ".")),
              price > 0
        else {
            return false
        }
        return true
    }

    public var currentPrice: Double {
        return Double(priceInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    public var currencySymbol: String {
        return CurrencyUtilities.symbol(for: selectedCurrency)
    }

    public var formattedWorkTime: String {
        guard isValidPrice,
              let hourlyWage = keychainManager.retrieveWage(),
              hourlyWage > 0
        else {
            return "Enter wage first"
        }

        let workTime = ConversionEngine.convertToWorkTime(price: currentPrice, hourlyWage: hourlyWage)
        return ConversionEngine.formatWorkTime(workTime)
    }

    // MARK: - Initialization

    public init() {
        setupBindings()
        loadInitialValues()
    }

    // MARK: - Public Methods

    public func handleScanResult(_ result: Result<[UIImage], Error>) {
        switch result {
        case let .success(images):
            if let firstImage = images.first {
                currentImage = firstImage
                processImage(firstImage)
            }
        case let .failure(error):
            ocrError = error.localizedDescription
        }
    }

    public func processImage(_ image: UIImage) {
        currentImage = image
        isProcessingOCR = true
        ocrError = nil

        performOCR(on: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessingOCR = false

                switch result {
                case let .success(extractedText):
                    self?.processExtractedText(extractedText)
                case let .failure(error):
                    self?.ocrError = error.localizedDescription
                }
            }
        }
    }

    public func saveCalculation() {
        guard isValidPrice,
              let hourlyWage = keychainManager.retrieveWage()
        else {
            return
        }

        let context = DataController.shared.container.viewContext
        let calculation = Calculation(context: context)

        calculation.price = currentPrice
        calculation.currency = selectedCurrency
        calculation.minutes = ConversionEngine.convertToWorkTime(price: currentPrice, hourlyWage: hourlyWage)
        calculation.timestamp = Date()

        // Save image data if available
        if let image = currentImage,
           let imageData = image.jpegData(compressionQuality: 0.8)
        {
            calculation.imageData = imageData
        }

        DataController.shared.save()

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Clear input for next calculation
        clearInput()
    }

    public func clearInput() {
        priceInput = ""
        currentImage = nil
        ocrError = nil
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Auto-format price input
        $priceInput
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] input in
                self?.formatPriceInput(input)
            }
            .store(in: &cancellables)
    }

    private func loadInitialValues() {
        selectedCurrency = keychainManager.retrieveCurrency()
    }

    private func formatPriceInput(_ input: String) {
        // Basic price formatting - ensure decimal format
        let cleanInput = input.replacingOccurrences(of: ",", with: ".")

        // Validate format
        let components = cleanInput.components(separatedBy: ".")
        if components.count > 2 {
            // Remove extra decimal points
            let integerPart = components[0]
            let decimalPart = components[1]
            let formatted = "\(integerPart).\(decimalPart)"

            if formatted != input {
                priceInput = formatted
            }
        }
    }

    private func performOCR(on image: UIImage, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")

            completion(.success(recognizedText))
        }

        // Configure OCR request
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en", "de"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    private func processExtractedText(_ text: String) {
        // Use regex to find price patterns
        if let (price, currency) = CurrencyUtilities.parsePrice(from: text) {
            priceInput = String(format: "%.2f", price)

            // Update currency if detected and supported
            if CurrencyUtilities.supportedCurrencies.keys.contains(currency) {
                selectedCurrency = currency
            }
        } else {
            // If no price found, try to extract just numbers
            extractNumbersFromText(text)
        }
    }

    private func extractNumbersFromText(_ text: String) {
        // Look for decimal numbers in the text
        let numberPattern = #"([0-9]+[.,][0-9]{2})|([0-9]+)"#

        if let range = text.range(of: numberPattern, options: .regularExpression) {
            let numberString = String(text[range])
            let cleanNumber = numberString.replacingOccurrences(of: ",", with: ".")

            if let _ = Double(cleanNumber) {
                priceInput = cleanNumber
            }
        }
    }
}

// MARK: - OCR Errors

public enum OCRError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .processingFailed:
            return "OCR processing failed"
        }
    }
}

// MARK: - UIKit Integration

import UIKit

extension PriceCaptureViewModel {
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}
