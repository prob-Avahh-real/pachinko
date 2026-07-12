import SwiftUI
import SpriteKit

// MARK: - Game View (SwiftUI wrapper)

struct GameView: View {
    @StateObject private var state = GameState()
    @State private var scene: BoardScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // SpriteKit Board
                if let scene = scene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()
                }

                // Overlay UI
                VStack {
                    // Top bar
                    HStack {
                        ScorePanel(state: state)
                        Spacer()
                        BallCounter(state: state)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geo.safeAreaInsets.top + 8)

                    Spacer()

                    // Fever progress
                    if !state.isFever && state.feverCount > 0 {
                        FeverProgressBar(count: state.feverCount)
                            .padding(.horizontal, 40)
                    }

                    // Power meter + launch button
                    HStack {
                        Spacer()
                        PowerMeterView(level: state.powerLevel)
                        LaunchButton(state: state) { power in
                            state.launchBall(power: power)
                            scene?.physics.onEvent?(PhysicsEvent(type: .launch, x: nil, y: nil))
                        }
                        Spacer()
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }

                // Fever overlay
                if state.isFever {
                    FeverOverlay()
                }

                // Game Over
                if state.isGameOver {
                    GameOverOverlay(state: state)
                }
            }
        }
        .onAppear {
            let s = BoardScene(size: UIScreen.main.bounds.size, state: state)
            scene = s
            s.onReady = { state.layout(in: s.size) }
        }
    }
}

// MARK: - Board Scene (SpriteKit)

final class BoardScene: SKScene {
    let physics: PhysicsEngine
    private unowned var state: GameState
    private var lastTime: TimeInterval?
    var onReady: (() -> Void)?

    private var pinNodes: [SKShapeNode] = []
    private var ballNodes: [UUID: SKShapeNode] = [:]
    private var pocketNodes: [SKShapeNode] = []
    private let audio = AudioEngine()

    init(size: CGSize, state: GameState) {
        self.state = state
        self.physics = PhysicsEngine(state: state)
        super.init(size: size)
        backgroundColor = UIColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 1) // Deep navy
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func didMove(to view: SKView) {
        onReady?()
        audio.start()
        buildBoard()
        setupPhysicsCallbacks()
    }

    private func buildBoard() {
        removeAllChildren()

        // Draw pins
        for pin in state.pins {
            let node = SKShapeNode(circleOfRadius: pin.radius)
            node.position = CGPoint(x: pin.x, y: size.height - pin.y)
            node.fillColor = UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.9)
            node.strokeColor = UIColor(red: 1, green: 0.7, blue: 0, alpha: 1)
            node.lineWidth = 0.5
            node.glowWidth = 2
            addChild(node)
            pinNodes.append(node)
        }

        // Draw pockets
        for pocket in state.pockets {
            let node = SKShapeNode(rect: CGRect(
                x: pocket.x - pocket.width/2,
                y: size.height - pocket.y - pocket.height/2,
                width: pocket.width,
                height: pocket.height
            ), cornerRadius: 8)
            node.fillColor = pocket.color.withAlphaComponent(0.6)
            node.strokeColor = pocket.color
            node.lineWidth = 2
            node.glowWidth = pocket.isFever ? 8 : 2

            // Label
            let label = SKLabelNode(text: pocket.label)
            label.fontSize = 10
            label.fontColor = .white
            label.fontName = "HelveticaNeue-Bold"
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: pocket.x, y: size.height - pocket.y)
            addChild(node)
            addChild(label)
            pocketNodes.append(node)
        }
    }

    private func setupPhysicsCallbacks() {
        physics.onEvent = { [weak self] event in
            guard let self else { return }
            DispatchQueue.main.async {
                switch event.type {
                case .pinHit:
                    self.audio.playPinHit()
                case .score:
                    self.audio.playScore(value: self.state.score % 100)
                case .drain:
                    self.audio.playDrain()
                case .feverStart:
                    self.audio.playFeverStart()
                case .launch:
                    self.audio.playLaunch()
                default: break
                }
            }
        }

        physics.onSpawnParticles = { [weak self] x, y, count, color in
            self?.spawnParticles(x: x, y: y, count: count, color: color)
        }
    }

    private func spawnParticles(x: CGFloat, y: CGFloat, count: Int, color: UIColor) {
        for _ in 0..<count {
            let p = SKShapeNode(circleOfRadius: 1.5 + CGFloat.random(in: 0...2.5))
            p.position = CGPoint(x: x, y: size.height - y)
            p.fillColor = color
            p.strokeColor = .clear

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed: CGFloat = 50 + CGFloat.random(in: 0...200)
            p.physicsBody = SKPhysicsBody(circleOfRadius: 1)
            p.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: -sin(angle) * speed - 60)
            p.physicsBody?.affectedByGravity = false
            p.physicsBody?.linearDamping = 2

            addChild(p)

            // Auto-remove after delay
            p.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.8),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard let last = lastTime else { lastTime = currentTime; return }
        let dt = currentTime - last
        lastTime = currentTime

        physics.tick(dt: dt)
        syncBallNodes()
    }

    private func syncBallNodes() {
        // Remove stale nodes
        let activeIDs = Set(state.balls.map(\.id))
        for (id, node) in ballNodes where !activeIDs.contains(id) {
            node.removeFromParent()
            ballNodes.removeValue(forKey: id)
        }

        // Update/create ball nodes
        for ball in state.balls {
            let pos = CGPoint(x: ball.x, y: size.height - ball.y)

            if let node = ballNodes[ball.id] {
                node.position = pos
            } else {
                let node = SKShapeNode(circleOfRadius: ball.radius)
                node.fillColor = UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1)
                node.strokeColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 0.8)
                node.lineWidth = 1.5
                node.glowWidth = 4
                node.position = pos
                addChild(node)
                ballNodes[ball.id] = node
            }
        }
    }
}

// MARK: - UI Components

struct ScorePanel: View {
    @ObservedObject var state: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SCORE").font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text("\(state.score)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            if state.multiplier > 1 {
                Text("×\(state.multiplier)")
                    .font(.caption).foregroundStyle(.pink).fontWeight(.bold)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BallCounter: View {
    @ObservedObject var state: GameState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(state.ballsRemaining, 10), id: \.self) { _ in
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 8, height: 8)
            }
            if state.ballsRemaining > 10 {
                Text("+\(state.ballsRemaining - 10)")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            Text("×\(state.ballsRemaining)")
                .font(.caption).foregroundStyle(.white).fontWeight(.medium)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PowerMeterView: View {
    let level: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.1))
                .frame(width: 24, height: 100)

            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [.green, .yellow, .orange, .red],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 24, height: 100 * level)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LaunchButton: View {
    @ObservedObject var state: GameState
    let onLaunch: (CGFloat) -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            onLaunch(state.powerLevel)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.3),
                                .pink.opacity(0.5),
                                .purple.opacity(0.8),
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)

                Text("发射")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .disabled(state.ballsRemaining <= 0 && state.balls.isEmpty)
        .opacity((state.ballsRemaining <= 0 && state.balls.isEmpty) ? 0.3 : 1)
    }
}

struct FeverProgressBar: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<GameConfig.feverThreshold, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < count ? .pink : .white.opacity(0.2))
                    .frame(height: 6)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FeverOverlay: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color.pink.opacity(0.15 + sin(phase) * 0.05)
                .ignoresSafeArea()

            VStack(spacing: 4) {
                Text("🔥 FEVER 🔥")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("×5 BONUS · +10 BALLS")
                    .font(.caption).foregroundStyle(.white).fontWeight(.bold)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

struct GameOverOverlay: View {
    @ObservedObject var state: GameState

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("游戏结束").font(.largeTitle).fontWeight(.bold).foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("最终得分").font(.caption).foregroundStyle(.white.opacity(0.6))
                    Text("\(state.score)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                }

                Button {
                    state.reset()
                } label: {
                    Text("再来一局")
                        .font(.headline).foregroundStyle(.white)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Capsule().fill(.pink))
                }
            }
        }
    }
}
