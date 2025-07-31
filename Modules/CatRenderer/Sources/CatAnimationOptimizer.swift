import SpriteKit

// swiftlint:disable force_unwrapping identifier_name
import UIKit

// MARK: - Cat Animation Optimizer

@available(iOS 15.0, *)
public class CatAnimationOptimizer {
    // MARK: - Singleton

    public static let shared = CatAnimationOptimizer()

    // MARK: - Properties

    private let atlas = SKTextureAtlas(named: "Cat")
    private lazy var frames: [SKTexture] = (0 ..< atlas.textureNames.count)
        .map { atlas.textureNamed("cat_\($0)") }
    private let cache = NSCache<NSString, SKTexture>()
    private var isInitialized = false
    private let cacheQueue = DispatchQueue(label: "com.lifemeter.texture-cache", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        cache.totalCostLimit = 20 * 1024 * 1024 // 20 MB
        cacheAtlas()
    }

    // MARK: - Public Methods

    /// Get cached textures for a cat state
    public func getTextures(for state: CatState) -> [SKTexture] {
        var textures: [SKTexture] = []
        for i in 0 ..< state.frameCount {
            let key = "cat_\(state.rawValue)_\(i)" as NSString
            if let cached = cache.object(forKey: key) {
                textures.append(cached)
            } else {
                let texture = atlas.textureNamed(key as String)
                texture.filteringMode = .nearest
                let cost = Int(texture.size().width * texture.size().height * 4)
                cache.setObject(texture, forKey: key, cost: cost)
                textures.append(texture)
            }
        }
        return textures
    }

    /// Check if cache is ready
    public var isCacheReady: Bool {
        return isInitialized
    }

    /// Generate widget snapshot from cached textures
    public func generateWidgetSnapshot(for state: CatState, frame: Int = 0) -> UIImage? {
        guard isCacheReady else { return nil }

        let textures = getTextures(for: state)
        guard !textures.isEmpty else { return nil }

        let frameIndex = min(frame, textures.count - 1)
        let texture = textures[frameIndex]

        return UIImage(cgImage: texture.cgImage())
    }

    /// Pre-warm cache (call during app startup)
    public func preWarmCache(completion: @escaping @Sendable () -> Void) {
        guard !isInitialized else {
            completion()
            return
        }

        SKTextureAtlas.preloadTextureAtlases([atlas]) { [weak self] in
            guard let self = self else { return }
            self.cacheQueue.async {
                self.loadAllTextures()

                DispatchQueue.main.async {
                    self.isInitialized = true
                    completion()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func populateTextureCache() {
        // Initialize cache in background to avoid blocking main thread
        SKTextureAtlas.preloadTextureAtlases([atlas]) { [weak self] in
            guard let self = self else { return }
            self.cacheQueue.async {
                self.loadAllTextures()

                DispatchQueue.main.async {
                    self.isInitialized = true
                    NotificationCenter.default.post(name: .catAnimationCacheReady, object: nil)
                }
            }
        }
    }

    private func loadAllTextures() {
        for state in CatState.allCases {
            _ = loadTexturesForState(state)
        }
    }

    private func loadTexturesForState(_ state: CatState) -> [SKTexture] {
        let frameCount = state.frameCount
        var textures: [SKTexture] = []

        for i in 0 ..< frameCount {
            let name = "cat_\(state.rawValue)_\(i)"
            let texture = atlas.textureNamed(name)
            texture.filteringMode = .nearest
            let cost = Int(texture.size().width * texture.size().height * 4)
            cache.setObject(texture, forKey: name as NSString, cost: cost)
            textures.append(texture)
        }

        return textures
    }
}

// MARK: - Cat State

public enum CatState: String, CaseIterable {
    case sleeping = "sleep"
    case walking = "walk"
    case running = "run"
    case pouncing = "pounce"

    var frameCount: Int {
        switch self {
        case .sleeping: return 4
        case .walking: return 8
        case .running: return 6
        case .pouncing: return 12
        }
    }

    var animationDuration: TimeInterval {
        switch self {
        case .sleeping: return 2.0
        case .walking: return 1.0
        case .running: return 0.6
        case .pouncing: return 0.8
        }
    }

    var shouldLoop: Bool {
        switch self {
        case .sleeping, .walking, .running: return true
        case .pouncing: return false
        }
    }
}

// MARK: - Optimized Cat Animation View

@available(iOS 15.0, *)
public class OptimizedCatAnimationView: UIView {
    // MARK: - Properties

    private let imageView = UIImageView()
    private var animationTimer: Timer?
    private var currentState: CatState = .sleeping
    private var currentFrame = 0
    private var isAnimating = false

    // MARK: - Initialization

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Wait for cache to be ready
        if CatAnimationOptimizer.shared.isCacheReady {
            startAnimation()
        } else {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(cacheReady),
                name: .catAnimationCacheReady,
                object: nil
            )
        }
    }

    @objc private func cacheReady() {
        NotificationCenter.default.removeObserver(self, name: .catAnimationCacheReady, object: nil)
        startAnimation()
    }

    // MARK: - Animation Control

    public func setState(_ state: CatState) {
        guard state != currentState else { return }

        currentState = state
        currentFrame = 0

        if isAnimating {
            stopAnimation()
            startAnimation()
        }
    }

    public func startAnimation() {
        guard CatAnimationOptimizer.shared.isCacheReady else { return }
        guard !isAnimating else { return }

        isAnimating = true
        currentFrame = 0

        let frameInterval = currentState.animationDuration / Double(currentState.frameCount)

        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.updateFrame()
        }

        updateFrame() // Show first frame immediately
    }

    public func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }

    public func pauseAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }

    public func resumeAnimation() {
        guard !isAnimating else { return }
        startAnimation()
    }

    private func updateFrame() {
        let textures = CatAnimationOptimizer.shared.getTextures(for: currentState)
        guard !textures.isEmpty else { return }

        let texture = textures[currentFrame]
        imageView.image = UIImage(cgImage: texture.cgImage())

        currentFrame += 1

        if currentFrame >= textures.count {
            if currentState.shouldLoop {
                currentFrame = 0
            } else {
                stopAnimation()
                currentFrame = textures.count - 1 // Stay on last frame
            }
        }
    }

    // MARK: - Lifecycle

    deinit {
        stopAnimation()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Widget Snapshot Generator

@available(iOS 15.0, *)
public class WidgetSnapshotGenerator {
    /// Generate snapshot for widget timeline
    public static func generateSnapshot(
        for state: CatState,
        frame: Int = 0,
        size: CGSize = CGSize(width: 100, height: 100)
    ) -> UIImage? {
        // Use cached textures for performance
        guard let image = CatAnimationOptimizer.shared.generateWidgetSnapshot(for: state, frame: frame) else {
            return generateFallbackImage(size: size)
        }

        // Resize to widget size
        return resizeImage(image, to: size)
    }

    /// Generate animated sequence for widget
    public static func generateAnimationSequence(
        for state: CatState,
        size: CGSize = CGSize(width: 100, height: 100)
    ) -> [UIImage] {
        let textures = CatAnimationOptimizer.shared.getTextures(for: state)
        guard !textures.isEmpty else {
            return [generateFallbackImage(size: size)].compactMap { $0 }
        }

        return textures.compactMap { texture in
            let image = UIImage(cgImage: texture.cgImage())
            return resizeImage(image, to: size)
        }
    }

    private static func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private static func generateFallbackImage(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        // Draw a simple cat silhouette as fallback
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemBlue.cgColor)

        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(ovalIn: rect.insetBy(dx: size.width * 0.2, dy: size.height * 0.2))
        path.fill()

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Performance Monitor

@available(iOS 15.0, *)
public class CatAnimationPerformanceMonitor {
    public static let shared = CatAnimationPerformanceMonitor()

    private var frameRenderTimes: [TimeInterval] = []
    private var lastFrameTime: CFTimeInterval = 0

    private init() {}

    public func recordFrameRender() {
        let currentTime = CACurrentMediaTime()

        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameRenderTimes.append(frameTime)

            // Keep only last 60 frames for rolling average
            if frameRenderTimes.count > 60 {
                frameRenderTimes.removeFirst()
            }
        }

        lastFrameTime = currentTime
    }

    public var averageFrameTime: TimeInterval {
        guard !frameRenderTimes.isEmpty else { return 0 }
        return frameRenderTimes.reduce(0, +) / Double(frameRenderTimes.count)
    }

    public var currentFPS: Double {
        let avgFrameTime = averageFrameTime
        return avgFrameTime > 0 ? 1.0 / avgFrameTime : 0
    }

    public var isPerformanceGood: Bool {
        return currentFPS >= 30.0 // Target 30+ FPS
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let catAnimationCacheReady = Notification.Name("catAnimationCacheReady")
}
