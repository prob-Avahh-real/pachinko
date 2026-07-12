import Foundation
import CoreGraphics

// MARK: - Game Configuration

enum GameConfig {
    static let pinCols = 9
    static let pinRows = 16
    static let pinRadius: CGFloat = 5
    static let ballRadius: CGFloat = 7
    static let gravity: CGFloat = 900
    static let pinBounce: CGFloat = 0.55
    static let friction: CGFloat = 0.998
    static let maxSpeed: CGFloat = 800
    static let initialBalls = 15
    static let feverThreshold = 5
    static let feverDuration: TimeInterval = 8.0
    static let maxActiveBalls = 5
    static let powerOscSpeed: CGFloat = 2.8

    static let pocketLabels = ["OUT", "×1", "×3", "×5", "FEVER", "×5", "×3", "×1", "OUT"]
    static let pocketValues = [0, 100, 300, 500, -1, 500, 300, 100, 0]

    static let pocketColors: [UIColor] = [
        UIColor(red: 0.2, green: 0, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.4, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.6, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.8, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.18, blue: 0.58, alpha: 1),
        UIColor(red: 1, green: 0.8, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.6, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.4, blue: 0, alpha: 1),
        UIColor(red: 0.2, green: 0, blue: 0, alpha: 1),
    ]
}

// MARK: - Game State

final class GameState: ObservableObject {
    @Published var score = 0
    @Published var multiplier = 1
    @Published var ballsRemaining = GameConfig.initialBalls
    @Published var feverCount = 0
    @Published var isFever = false
    @Published var isGameOver = false
    @Published var comboCount = 0
    @Published var powerLevel: CGFloat = 0.5
    @Published var balls: [Ball] = []
    @Published var pins: [Pin] = []
    @Published var pockets: [Pocket] = []
    @Published var particles: [Particle] = []

    var feverTimer: TimeInterval = 0
    var powerDir: CGFloat = 1
    var screenShake: CGFloat = 0
    var lastPocketTime: TimeInterval = 0

    private(set) var boardRect: CGRect = .zero

    func layout(in size: CGSize) {
        let padX: CGFloat = 16
        let padTop: CGFloat = 60
        let padBottom: CGFloat = 140
        let bw = size.width * 0.88 - padX
        let bh = size.height - padTop - padBottom

        boardRect = CGRect(x: padX, y: padTop, width: bw, height: bh)
        let pinStartY = padTop + 45
        let pinEndY = padTop + bh - 85
        let pocketY = pinEndY + 35

        // Build pins
        pins.removeAll()
        let psX = bw / CGFloat(GameConfig.pinCols + 1)
        let psY = (pinEndY - pinStartY) / CGFloat(GameConfig.pinRows)

        for row in 0..<GameConfig.pinRows {
            let offX = (row % 2 == 0) ? 0 : psX * 0.5
            for col in 0..<GameConfig.pinCols {
                pins.append(Pin(
                    x: padX + psX + CGFloat(col) * psX + offX,
                    y: pinStartY + CGFloat(row) * psY
                ))
            }
        }

        // Build pockets
        pockets.removeAll()
        let pkH: CGFloat = 50
        let pkCount = 9
        let pkW = bw / CGFloat(pkCount + 1)

        for i in 0..<pkCount {
            let cx = padX + CGFloat(i + 1) * pkW
            pockets.append(Pocket(
                x: cx - pkW * 0.4,
                y: pocketY,
                width: pkW * 0.8,
                height: pkH,
                label: GameConfig.pocketLabels[i],
                value: GameConfig.pocketValues[i],
                color: GameConfig.pocketColors[i],
                isFever: i == pkCount / 2
            ))
        }
    }

    func launchBall(power: CGFloat) {
        guard ballsRemaining > 0, balls.count < GameConfig.maxActiveBalls else { return }

        let cx = boardRect.midX
        let lx = cx + CGFloat.random(in: -35...35) * power
        let ly = boardRect.minY + 45 - 35

        balls.append(Ball(
            x: lx, y: ly,
            vx: CGFloat.random(in: -50...50),
            vy: -280 - power * 650
        ))
        ballsRemaining -= 1
    }

    func reset() {
        score = 0
        multiplier = 1
        ballsRemaining = GameConfig.initialBalls
        feverCount = 0
        isFever = false
        isGameOver = false
        comboCount = 0
        powerLevel = 0.5
        powerDir = 1
        screenShake = 0
        lastPocketTime = 0
        feverTimer = 0
        balls.removeAll()
        particles.removeAll()
    }
}

// MARK: - Pin

struct Pin: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat = GameConfig.pinRadius
}

// MARK: - Ball

struct Ball: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    let radius: CGFloat = GameConfig.ballRadius
    var hitCount = 0
    var active = true
}

// MARK: - Pocket

struct Pocket: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let label: String
    let value: Int
    let color: UIColor
    let isFever: Bool
}

// MARK: - Particle

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    let maxLife: CGFloat
    let color: UIColor
    var size: CGFloat
}
