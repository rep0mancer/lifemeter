import CalcCore
import SwiftUI

// MARK: - Optimized Cat Animation View

@available(iOS 15.0, *)
public struct OptimizedCatAnimationView: View {
    // MARK: - Properties

    let workMinutes: Double
    let size: CGFloat

    @State private var currentFrame: Int = 0
    @State private var isAnimating: Bool = true
    @State private var animationTimer: Timer?

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    // MARK: - Initialization

    public init(workMinutes: Double = 0, size: CGFloat = 64) {
        self.workMinutes = workMinutes
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if CatAnimationOptimizer.shared.isCacheReady {
                optimizedAnimationView
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            startOptimizedAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: catState) { _ in
            restartAnimation()
        }
    }

    // MARK: - Optimized Animation View

    @ViewBuilder
    private var optimizedAnimationView: some View {
        if let snapshot = CatAnimationOptimizer.shared.generateWidgetSnapshot(
            for: catState,
            frame: currentFrame
        ) {
            Image(uiImage: snapshot)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackView
        }
    }

    // MARK: - Fallback View

    @ViewBuilder
    private var fallbackView: some View {
        Image(systemName: catState.systemIcon)
            .font(.system(size: size * 0.6))
            .foregroundColor(catState.color)
            .symbolEffect(.pulse, isActive: isAnimating)
    }

    // MARK: - Animation Control

    private func startOptimizedAnimation() {
        guard CatAnimationOptimizer.shared.isCacheReady else {
            // Wait for cache to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startOptimizedAnimation()
            }
            return
        }

        stopAnimation()

        let frameInterval = catState.animationDuration / Double(catState.frameCount)

        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            updateFrame()
        }

        isAnimating = true
    }

    private func updateFrame() {
        // Record frame render time for performance monitoring
        CatAnimationPerformanceMonitor.shared.recordFrameRender()

        currentFrame = (currentFrame + 1) % catState.frameCount

        // Stop animation if it's a one-shot animation
        if !catState.shouldLoop, currentFrame == 0 {
            stopAnimation()
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }

    private func restartAnimation() {
        currentFrame = 0
        startOptimizedAnimation()
    }
}

// MARK: - Cat State Extensions for Optimization

extension CatState {
    var systemIcon: String {
        switch self {
        case .sleeping:
            return "zzz"
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .pouncing:
            return "hare.fill"
        }
    }

    var color: Color {
        switch self {
        case .sleeping:
            return .green
        case .walking:
            return .blue
        case .running:
            return .orange
        case .pouncing:
            return .red
        }
    }
}

// MARK: - Performance-Aware Cat Animation View

@available(iOS 15.0, *)
public struct PerformanceAwareCatAnimationView: View {
    // MARK: - Properties

    let workMinutes: Double
    let size: CGFloat

    @State private var useOptimizedAnimation = true
    @State private var performanceCheckTimer: Timer?

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    // MARK: - Initialization

    public init(workMinutes: Double, size: CGFloat = 64) {
        self.workMinutes = workMinutes
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if useOptimizedAnimation {
                OptimizedCatAnimationView(workMinutes: workMinutes, size: size)
            } else {
                // Fallback to simple static view for better performance
                Image(systemName: catState.systemIcon)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(catState.color)
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            startPerformanceMonitoring()
        }
        .onDisappear {
            stopPerformanceMonitoring()
        }
    }

    // MARK: - Performance Monitoring

    private func startPerformanceMonitoring() {
        performanceCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            checkPerformance()
        }
    }

    private func stopPerformanceMonitoring() {
        performanceCheckTimer?.invalidate()
        performanceCheckTimer = nil
    }

    private func checkPerformance() {
        let isPerformanceGood = CatAnimationPerformanceMonitor.shared.isPerformanceGood

        if !isPerformanceGood, useOptimizedAnimation {
            // Switch to static view if performance is poor
            withAnimation(.easeInOut(duration: 0.3)) {
                useOptimizedAnimation = false
            }
        } else if isPerformanceGood, !useOptimizedAnimation {
            // Switch back to animated view if performance improves
            withAnimation(.easeInOut(duration: 0.3)) {
                useOptimizedAnimation = true
            }
        }
    }
}

// MARK: - Widget Cat Animation View

@available(iOS 15.0, *)
public struct WidgetCatAnimationView: View {
    // MARK: - Properties

    let workMinutes: Double
    let size: CGFloat

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    // MARK: - Initialization

    public init(workMinutes: Double, size: CGFloat = 40) {
        self.workMinutes = workMinutes
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        // Use static snapshot for widgets to save battery
        if let snapshot = WidgetSnapshotGenerator.generateSnapshot(
            for: catState,
            frame: 0, // Use first frame for static display
            size: CGSize(width: size, height: size)
        ) {
            Image(uiImage: snapshot)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback to system icon
            Image(systemName: catState.systemIcon)
                .font(.system(size: size * 0.6))
                .foregroundColor(catState.color)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Animated Cat Sequence View (for special occasions)

@available(iOS 15.0, *)
public struct AnimatedCatSequenceView: View {
    // MARK: - Properties

    let workMinutes: Double
    let size: CGFloat

    @State private var currentImageIndex = 0
    @State private var animationImages: [UIImage] = []
    @State private var animationTimer: Timer?

    private var catState: CatState {
        ConversionEngine.catState(for: workMinutes)
    }

    // MARK: - Initialization

    public init(workMinutes: Double, size: CGFloat = 64) {
        self.workMinutes = workMinutes
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if !animationImages.isEmpty {
                Image(uiImage: animationImages[currentImageIndex])
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                // Loading or fallback
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            loadAnimationSequence()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    // MARK: - Animation Loading

    private func loadAnimationSequence() {
        let sequence = WidgetSnapshotGenerator.generateAnimationSequence(
            for: catState,
            size: CGSize(width: size, height: size)
        )

        animationImages = sequence

        if !animationImages.isEmpty {
            startAnimation()
        }
    }

    private func startAnimation() {
        stopAnimation()

        let frameInterval = catState.animationDuration / Double(animationImages.count)

        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            currentImageIndex = (currentImageIndex + 1) % animationImages.count
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct OptimizedCatAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            HStack(spacing: 16) {
                VStack {
                    OptimizedCatAnimationView(workMinutes: 2, size: 80)
                    Text("Sleeping")
                        .font(.caption)
                }

                VStack {
                    OptimizedCatAnimationView(workMinutes: 8, size: 80)
                    Text("Walking")
                        .font(.caption)
                }
            }

            HStack(spacing: 16) {
                VStack {
                    OptimizedCatAnimationView(workMinutes: 20, size: 80)
                    Text("Running")
                        .font(.caption)
                }

                VStack {
                    OptimizedCatAnimationView(workMinutes: 45, size: 80)
                    Text("Pouncing")
                        .font(.caption)
                }
            }

            // Performance-aware version
            VStack {
                PerformanceAwareCatAnimationView(workMinutes: 15, size: 100)
                Text("Performance-Aware")
                    .font(.caption)
            }
        }
        .padding()
    }
}
