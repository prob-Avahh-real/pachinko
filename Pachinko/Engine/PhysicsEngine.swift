import Foundation
import CoreGraphics

/// Physics tick result
struct PhysicsEvent {
    enum EventType {
        case pinHit, score(Int, Bool, Int), drain, feverProgress(Int), feverStart, feverEnd, gameOver, launch
    }
    let type: EventType
    let x: CGFloat?
    let y: CGFloat?
}

final class PhysicsEngine {
    unowned var state: GameState
    var onEvent: ((PhysicsEvent) -> Void)?
    var onSpawnParticles: ((CGFloat, CGFloat, Int, UIColor) -> Void)?

    init(state: GameState) { self.state = state }

    func tick(dt: TimeInterval) {
        let dt = CGFloat(min(dt, 1/30)) // Cap delta

        // Power meter oscillation
        state.powerLevel += state.powerDir * GameConfig.powerOscSpeed * dt
        if state.powerLevel >= 1.0 { state.powerLevel = 1.0; state.powerDir = -1 }
        else if state.powerLevel <= 0.1 { state.powerLevel = 0.1; state.powerDir = 1 }

        // Fever timer
        if state.isFever {
            state.feverTimer -= dt
            if state.feverTimer <= 0 {
                state.isFever = false
                state.multiplier = 1
                state.screenShake = 0
                onEvent?(PhysicsEvent(type: .feverEnd, x: nil, y: nil))
            }
        }

        // Screen shake decay
        if state.screenShake > 0 {
            state.screenShake *= 0.91
            if state.screenShake < 0.001 { state.screenShake = 0 }
        }

        // Update particles
        updateParticles(dt)

        // Update balls
        let boardLeft = state.boardRect.minX
        let boardRight = state.boardRect.maxX
        let pocketTop = state.pockets.first?.y ?? 0

        for i in (0..<state.balls.count).reversed() {
            var ball = state.balls[i]
            guard ball.active else { continue }

            // Gravity & friction
            ball.vy += GameConfig.gravity * dt
            ball.vx *= GameConfig.friction
            ball.vy *= GameConfig.friction

            // Speed clamp
            let speed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
            if speed > GameConfig.maxSpeed {
                let s = GameConfig.maxSpeed / speed
                ball.vx *= s
                ball.vy *= s
            }

            ball.x += ball.vx * dt
            ball.y += ball.vy * dt

            // Wall bounce
            if ball.x - ball.radius < boardLeft {
                ball.x = boardLeft + ball.radius
                ball.vx *= -0.6
            }
            if ball.x + ball.radius > boardRight {
                ball.x = boardRight - ball.radius
                ball.vx *= -0.6
            }

            // Pin collision
            for pin in state.pins {
                let dx = ball.x - pin.x
                let dy = ball.y - pin.y
                let dist = sqrt(dx*dx + dy*dy)
                let minDist = ball.radius + pin.radius

                if dist < minDist && dist > 0 {
                    let overlap = minDist - dist
                    let nx = dx / dist
                    let ny = dy / dist
                    ball.x += nx * overlap
                    ball.y += ny * overlap

                    let vn = ball.vx * nx + ball.vy * ny
                    if vn < 0 {
                        ball.vx -= (1 + GameConfig.pinBounce) * vn * nx
                        ball.vy -= (1 + GameConfig.pinBounce) * vn * ny
                    }
                    ball.vx += CGFloat.random(in: -17...17)
                    ball.vy += CGFloat.random(in: -17...17)
                    ball.hitCount += 1

                    if ball.hitCount % 3 == 0 {
                        onEvent?(PhysicsEvent(type: .pinHit, x: ball.x, y: ball.y))
                        onSpawnParticles?(ball.x, ball.y, 2, UIColor(red: 1, green: 0.84, blue: 0, alpha: 1))
                    }
                    break // One collision per tick
                }
            }

            // Pocket detection
            if ball.y + ball.radius >= pocketTop && ball.y < pocketTop + 65 {
                var pocketed = false
                for pocket in state.pockets {
                    if ball.x > pocket.x && ball.x < pocket.x + pocket.width &&
                        ball.y + ball.radius >= pocket.y {
                        resolvePocket(&ball, pocket)
                        state.balls.remove(at: i)
                        pocketed = true
                        break
                    }
                }
                if pocketed { continue }
            }

            // Fell off screen
            if ball.y > pocketTop + 80 {
                state.comboCount = 0
                onSpawnParticles?(ball.x, ball.y + 10, 5, UIColor(red: 0.4, green: 0, blue: 0, alpha: 1))
                onEvent?(PhysicsEvent(type: .drain, x: nil, y: nil))
                state.balls.remove(at: i)
                continue
            }

            state.balls[i] = ball
        }

        // Game over check
        if state.ballsRemaining <= 0 && state.balls.isEmpty && !state.isFever && !state.isGameOver {
            state.isGameOver = true
            onEvent?(PhysicsEvent(type: .gameOver, x: nil, y: nil))
        }
    }

    private func resolvePocket(_ ball: inout Ball, _ pocket: Pocket) {
        if pocket.isFever {
            state.feverCount += 1
            onSpawnParticles?(ball.x, ball.y, 22, UIColor(red: 1, green: 0.18, blue: 0.58, alpha: 1))

            if state.feverCount >= GameConfig.feverThreshold && !state.isFever {
                state.isFever = true
                state.feverTimer = GameConfig.feverDuration
                state.multiplier = 5
                state.ballsRemaining += 10
                state.feverCount = 0
                state.screenShake = 0.6
                state.isGameOver = false
                onSpawnParticles?(state.boardRect.midX, state.boardRect.minY + 100, 40,
                                  UIColor(red: 1, green: 0.18, blue: 0.58, alpha: 1))
                onEvent?(PhysicsEvent(type: .feverStart, x: nil, y: nil))
                return
            }

            if state.isFever {
                state.score += 1000 * state.multiplier
                onSpawnParticles?(ball.x, ball.y, 20, UIColor(red: 1, green: 0.84, blue: 0, alpha: 1))
                onEvent?(PhysicsEvent(type: .score(1000, true, 0), x: ball.x, y: ball.y))
                return
            }

            onEvent?(PhysicsEvent(type: .feverProgress(state.feverCount), x: nil, y: nil))
            return
        }

        if pocket.value > 0 {
            let now = CACurrentMediaTime()
            if now - state.lastPocketTime < 1.5 {
                state.comboCount += 1
            } else {
                state.comboCount = 0
            }
            state.lastPocketTime = now

            let comboBonus = CGFloat(min(state.comboCount, 5)) * 0.2
            let pts = Int(CGFloat(pocket.value) * CGFloat(state.multiplier) * (1 + comboBonus))
            state.score += pts

            let count = pocket.value >= 500 ? 15 : 8
            onSpawnParticles?(ball.x, ball.y, count, pocket.color)
            onEvent?(PhysicsEvent(type: .score(pts, false, state.comboCount > 0 ? state.comboCount + 1 : 0),
                                  x: ball.x, y: ball.y))
            return
        }

        // Drain
        state.comboCount = 0
        onSpawnParticles?(ball.x, ball.y + 10, 5, UIColor(red: 0.4, green: 0, blue: 0, alpha: 1))
        onEvent?(PhysicsEvent(type: .drain, x: nil, y: nil))
    }

    private func updateParticles(_ dt: CGFloat) {
        for i in (0..<state.particles.count).reversed() {
            state.particles[i].life -= dt
            if state.particles[i].life <= 0 {
                state.particles.remove(at: i)
                continue
            }
            state.particles[i].x += state.particles[i].vx * dt
            state.particles[i].y += state.particles[i].vy * dt
            state.particles[i].vy += 280 * dt
            state.particles[i].size *= 0.995
        }
    }
}
