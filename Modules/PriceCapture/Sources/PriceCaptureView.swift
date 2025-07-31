import CalcCore
import HistoryStore
import SwiftUI
import VisionKit

// MARK: - Price Capture View

@available(iOS 15.0, *)
public struct PriceCaptureView: View {
    @StateObject private var viewModel = PriceCaptureViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                // Glass-morphism background
                Color.black.opacity(0.05)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    headerSection
                    priceInputSection
                    captureOptionsSection
                    resultSection

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Price Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showDocumentScanner) {
            DocumentScannerView { result in
                viewModel.handleScanResult(result)
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView { image in
                viewModel.processImage(image)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Enter or scan a price")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
    }

    private var priceInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                TextField("0.00", text: $viewModel.priceInput)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(viewModel.isValidPrice ? .blue : .clear, lineWidth: 2)
                    )

                VStack {
                    Text(viewModel.currencySymbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)

                    Button(action: {
                        viewModel.showCurrencyPicker.toggle()
                    }) {
                        Text(viewModel.selectedCurrency)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.leading, 8)
            }

            if viewModel.showCurrencyPicker {
                currencyPickerSection
            }
        }
    }

    private var currencyPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(CurrencyUtilities.supportedCurrencies.keys.sorted()), id: \.self) { currency in
                    Button(action: {
                        viewModel.selectedCurrency = currency
                        viewModel.showCurrencyPicker = false
                    }) {
                        HStack {
                            Text(CurrencyUtilities.symbol(for: currency))
                            Text(currency)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.selectedCurrency == currency ? .blue : .regularMaterial)
                        )
                        .foregroundColor(viewModel.selectedCurrency == currency ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .transition(.opacity)
    }

    private var captureOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Or capture from:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                // Document Scanner Button
                Button(action: {
                    viewModel.showDocumentScanner = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)

                        Text("Scan Receipt")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(width: 100, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                }

                // Photo Library Button
                Button(action: {
                    viewModel.showImagePicker = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 32))
                            .foregroundColor(.green)

                        Text("From Photos")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(width: 100, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                }
            }
        }
    }

    private var resultSection: some View {
        Group {
            if viewModel.isValidPrice {
                VStack(spacing: 16) {
                    Divider()

                    VStack(spacing: 8) {
                        Text("Work time required:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(viewModel.formattedWorkTime)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        viewModel.saveCalculation()
                    }) {
                        Text("Save Calculation")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.blue)
                            )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isValidPrice)
    }
}

// MARK: - Document Scanner Wrapper

@available(iOS 15.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    let completion: @Sendable (Result<[UIImage], Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_: VNDocumentCameraViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: @Sendable (Result<[UIImage], Error>) -> Void

        init(completion: @escaping @Sendable (Result<[UIImage], Error>) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0 ..< scan.pageCount {
                images.append(scan.imageOfPage(at: pageIndex))
            }
            completion(.success(images))
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion(.failure(error))
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Image Picker Wrapper

@available(iOS 15.0, *)
struct ImagePickerView: UIViewControllerRepresentable {
    let completion: @Sendable (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: @Sendable (UIImage) -> Void

        init(completion: @escaping @Sendable (UIImage) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct PriceCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        PriceCaptureView()
    }
}
