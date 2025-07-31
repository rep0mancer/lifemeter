import CalcCore
import SwiftUI

// MARK: - Cat Animation View

@available(iOS 15.0, *)
public struct CatAnimationView: View {
    let workMinutes: Double
    let size: CGFloat

    @State private var currentFrame: Int = 0
    @State private var isAnimating: Bool = true

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    private var frameCount: Int {
        switch catState {
        case .sleep: return 4
        case .walk: return 6
        case .run: return 8
        case .pounce: return 8
        }
    }

    public init(workMinutes: Double, size: CGFloat = 64) {
        self.workMinutes = workMinutes
        self.size = size
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / catState.frameRate)) { timeline in
            Image("cat_\(catState.rawValue)_\(currentFrame)")
                .resizable()
                .interpolation(.none) // Preserve pixel art crisp edges
                .frame(width: size, height: size)
                .onReceive(timeline) { _ in
                    if isAnimating {
                        withAnimation(.linear(duration: 0)) {
                            currentFrame = (currentFrame + 1) % frameCount
                        }
                    }
                }
        }
        .onAppear {
            currentFrame = 0
            isAnimating = true
        }
        .onChange(of: catState) { _ in
            // Reset animation when state changes
            currentFrame = 0
        }
    }
}

// MARK: - Cat Sprite Manager

@available(iOS 15.0, *)
public class CatSpriteManager: ObservableObject {
    public static let shared = CatSpriteManager()

    private var spriteCache: [String: UIImage] = [:]

    private init() {
        preloadSprites()
    }

    public func getSprite(state: CatState, frame: Int) -> UIImage? {
        let key = "cat_\(state.rawValue)_\(frame)"
        return spriteCache[key]
    }

    private func preloadSprites() {
        // Load all sprite frames into memory for smooth animation
        for state in CatState.allCases {
            let frameCount = getFrameCount(for: state)

            for frame in 0 ..< frameCount {
                let imageName = "cat_\(state.rawValue)_\(frame)"
                if let image = UIImage(named: imageName) {
                    spriteCache[imageName] = image
                }
            }
        }
    }

    private func getFrameCount(for state: CatState) -> Int {
        switch state {
        case .sleep: return 4
        case .walk: return 6
        case .run: return 8
        case .pounce: return 8
        }
    }
}

// MARK: - Cat State Indicator

@available(iOS 15.0, *)
public struct CatStateIndicator: View {
    let workMinutes: Double
    let showDetails: Bool

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    public init(workMinutes: Double, showDetails: Bool = false) {
        self.workMinutes = workMinutes
        self.showDetails = showDetails
    }

    public var body: some View {
        VStack(spacing: 8) {
            CatAnimationView(workMinutes: workMinutes, size: showDetails ? 80 : 48)

            if showDetails {
                VStack(spacing: 4) {
                    Text(catState.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(catState.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Widget Cat View (Simplified for WidgetKit)

@available(iOS 15.0, *)
public struct WidgetCatView: View {
    let workMinutes: Double
    let size: CGFloat

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    // For widgets, use a static frame based on current time
    private var staticFrame: Int {
        let timeInterval = Date().timeIntervalSince1970
        let frameCount = getFrameCount(for: catState)
        return Int(timeInterval / (1.0 / catState.frameRate)) % frameCount
    }

    public init(workMinutes: Double, size: CGFloat = 32) {
        self.workMinutes = workMinutes
        self.size = size
    }

    public var body: some View {
        Image("cat_\(catState.rawValue)_\(staticFrame)")
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
    }

    private func getFrameCount(for state: CatState) -> Int {
        switch state {
        case .sleep: return 4
        case .walk: return 6
        case .run: return 8
        case .pounce: return 8
        }
    }
}

// MARK: - Cat Animation Controls

@available(iOS 15.0, *)
public struct CatAnimationControls: View {
    @Binding var isPlaying: Bool
    @Binding var animationSpeed: Double

    public init(isPlaying: Binding<Bool>, animationSpeed: Binding<Double>) {
        _isPlaying = isPlaying
        _animationSpeed = animationSpeed
    }

    public var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            VStack(spacing: 4) {
                Text("Speed")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Slider(value: $animationSpeed, in: 0.5 ... 3.0, step: 0.5) {
                    Text("Animation Speed")
                } minimumValueLabel: {
                    Text("0.5x")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("3x")
                        .font(.caption2)
                }
                .frame(width: 120)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct CatAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            CatStateIndicator(workMinutes: 2, showDetails: true)
            CatStateIndicator(workMinutes: 15, showDetails: true)
            CatStateIndicator(workMinutes: 60, showDetails: true)
            CatStateIndicator(workMinutes: 180, showDetails: true)
        }
        .padding()
    }
}
