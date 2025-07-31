import SwiftUI
import VisionKit

// MARK: - Enhanced OCR View
@available(iOS 15.0, *)
public struct EnhancedOCRView: View {

    // MARK: - Properties
    @StateObject private var viewModel = OCRViewModel()
    @EnvironmentObject private var currency: CurrencyStore
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                scanButtonSection
                recentScansSection
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingScanner) {
            OCRScannerViewController.SwiftUIWrapper(delegate: viewModel)
        }
        .overlay(
            ToastOverlay(toast: $viewModel.currentToast)
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Scan Receipt Price")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Point your camera at a receipt to automatically detect prices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Scan Button Section
    private var scanButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: viewModel.startScanning) {
                HStack {
                    if viewModel.isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "camera.fill")
                    }
                    
                    Text(viewModel.isScanning ? "Scanning..." : "Start Scanning")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.isScanning)
            
            // Tips Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips for better scanning:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    TipRow(icon: "lightbulb", text: "Ensure good lighting")
                    TipRow(icon: "rectangle.center.inset.filled", text: "Keep receipt flat and in frame")
                    TipRow(icon: "hand.raised", text: "Hold camera steady")
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Recent Scans Section
    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.recentScans.isEmpty {
                Text("Recent Scans")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.recentScans.prefix(3), id: \.id) { scan in
                        RecentScanRow(scan: scan) {
                            viewModel.selectRecentScan(scan)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - OCR View Model
@available(iOS 15.0, *)
public class OCRViewModel: ObservableObject, OCRScannerDelegate {
    
    // MARK: - Published Properties
    @Published var showingScanner = false
    @Published var isScanning = false
    @Published var currentToast: ToastData?
    @Published var recentScans: [ScannedPrice] = []
    
    // MARK: - Public Methods
    
    public func startScanning() {
        isScanning = true
        showingScanner = true
    }
    
    public func selectRecentScan(_ scan: ScannedPrice) {
        showSuccessToast(price: scan.price, currency: scan.currency)
        // Notify parent about selected price
        NotificationCenter.default.post(
            name: .priceScanned,
            object: nil,
            userInfo: ["price": scan.price, "currency": scan.currency]
        )
    }
    
    // MARK: - OCR Scanner Delegate
    
    public func ocrScannerDidDetectPrice(_ price: Double, confidence: Float) {
        DispatchQueue.main.async {
            self.isScanning = false
            self.showingScanner = false
            
            // Add to recent scans
            let scan = ScannedPrice(
                price: price,
                currency: currency.selected,
                confidence: confidence,
                timestamp: Date()
            )
            self.recentScans.insert(scan, at: 0)
            
            // Keep only last 10 scans
            if self.recentScans.count > 10 {
                self.recentScans = Array(self.recentScans.prefix(10))
            }
            
            // Show success toast
            self.showSuccessToast(price: price, currency: scan.currency)
            
            // Notify parent
            NotificationCenter.default.post(
                name: .priceScanned,
                object: nil,
                userInfo: ["price": price, "currency": scan.currency]
            )
        }
    }
    
    public func ocrScannerDidFail(with error: OCRError) {
        DispatchQueue.main.async {
            self.isScanning = false
            self.showingScanner = false
            
            // Show error toast
            self.showErrorToast(message: error.localizedDescription)
            
            // Auto-focus back on scan button after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Focus would be handled by accessibility or UI state
            }
        }
    }
    
    public func ocrScannerDidCancel() {
        DispatchQueue.main.async {
            self.isScanning = false
            self.showingScanner = false
        }
    }
    
    // MARK: - Private Methods
    
    private func showSuccessToast(price: Double, currency: String) {
        let formattedPrice = CurrencyUtilities.formatPrice(price, currency: currency)
        let message = "Price \(formattedPrice) scanned—converting now."
        
        currentToast = ToastData(
            message: message,
            style: .success,
            duration: 3.0
        )
    }
    
    private func showErrorToast(message: String) {
        currentToast = ToastData(
            message: message,
            style: .error,
            duration: 4.0
        )
    }
}

// MARK: - Scanned Price Model
public struct ScannedPrice: Identifiable {
    public let id = UUID()
    public let price: Double
    public let currency: String
    public let confidence: Float
    public let timestamp: Date
    
    public var formattedPrice: String {
        return CurrencyUtilities.formatPrice(price, currency: currency)
    }
    
    public var confidenceText: String {
        let percentage = Int(confidence * 100)
        return "\(percentage)% confidence"
    }
}

// MARK: - Tip Row
private struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 12)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Recent Scan Row
private struct RecentScanRow: View {
    let scan: ScannedPrice
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(scan.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(scan.confidenceText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast Data
public struct ToastData: Identifiable {
    public let id = UUID()
    public let message: String
    public let style: ToastStyle
    public let duration: TimeInterval
    
    public enum ToastStyle {
        case success
        case error
        case info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
}

// MARK: - Toast Overlay
private struct ToastOverlay: View {
    @Binding var toast: ToastData?
    
    var body: some View {
        if let toast = toast {
            VStack {
                HStack {
                    Image(systemName: toast.style.icon)
                        .foregroundColor(.white)
                    
                    Text(toast.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(16)
                .background(toast.style.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.toast = nil
                    }
                }
            }
        }
    }
}

// MARK: - OCR Scanner SwiftUI Wrapper
@available(iOS 15.0, *)
extension OCRScannerViewController {
    
    struct SwiftUIWrapper: UIViewControllerRepresentable {
        weak var delegate: OCRScannerDelegate?
        
        func makeUIViewController(context: Context) -> OCRScannerViewController {
            let controller = OCRScannerViewController()
            controller.delegate = delegate
            return controller
        }
        
        func updateUIViewController(_ uiViewController: OCRScannerViewController, context: Context) {
            // No updates needed
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let priceScanned = Notification.Name("priceScanned")
}

// MARK: - Preview
@available(iOS 15.0, *)
struct EnhancedOCRView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedOCRView()
            .environmentObject(CurrencyStore())
    }
}

