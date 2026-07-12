import XCTest
@testable import Pachinko

final class PachinkoTests: XCTestCase {

    func testGameConfigConstants() {
        XCTAssertEqual(GameConfig.pinCols, 9)
        XCTAssertEqual(GameConfig.pinRows, 16)
        XCTAssertEqual(GameConfig.initialBalls, 15)
        XCTAssertEqual(GameConfig.feverThreshold, 5)
    }

    func testPocketLabels() {
        XCTAssertEqual(GameConfig.pocketLabels.count, 9)
        XCTAssertEqual(GameConfig.pocketLabels[0], "OUT")
        XCTAssertEqual(GameConfig.pocketLabels[4], "FEVER")
    }

    func testPocketValues() {
        XCTAssertEqual(GameConfig.pocketValues.count, 9)
        XCTAssertEqual(GameConfig.pocketValues[0], 0)
        XCTAssertEqual(GameConfig.pocketValues[1], 100)
        XCTAssertEqual(GameConfig.pocketValues[4], -1)
    }

    func testBallState() {
        let ball = Ball(position: CGPoint(x: 100, y: 100))
        XCTAssertEqual(ball.position.x, 100)
        XCTAssertEqual(ball.position.y, 100)
        XCTAssertEqual(ball.velocity, .zero)
        XCTAssertFalse(ball.isActive)
        XCTAssertFalse(ball.isLaunched)
    }

    func testPin() {
        let pin = Pin(position: CGPoint(x: 200, y: 300))
        XCTAssertEqual(pin.position.x, 200)
        XCTAssertEqual(pin.position.y, 300)
        XCTAssertFalse(pin.isHit)
    }

    func testGameState() {
        let state = GameState()
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.remainingBalls, GameConfig.initialBalls)
        XCTAssertFalse(state.isFeverMode)
        XCTAssertEqual(state.activeBallCount, 0)
    }
}
