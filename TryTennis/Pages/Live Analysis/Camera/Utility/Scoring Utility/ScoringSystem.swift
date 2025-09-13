import Foundation

class ScoringSystem {
    // --- Scoring Counters ---
    private var totalAttempts: Int = 0
    private var successfulShots: Int = 0
    private var failedShots: Int = 0

    // --- Dependency Injection from BallTracker ---
    private let ballTracker: BallTracker
    public init(ballTracker: BallTracker) {
        self.ballTracker = ballTracker
    }
    private var ballTrajectory: [BallPosition] {
        return ballTracker.ballTrajectory
    }
    private var ballVelocity: CGPoint {
        return ballTracker.ballVelocity
    }
    private var confirmedNetPosition: CGRect? {
        return ballTracker.confirmedNetPosition
    }
    private var ballSideHistory: [String] {
        return ballTracker.ballSideHistory
    }
    private var crossingInProgress: Bool {
        return ballTracker.crossingInProgress
    }

    // --- Net State (local to scoring logic) ---
    private var lastBallSide: String? = nil // "left" or "right"
    private var netBox: CGRect? = nil
    private var netTopY: CGFloat = 0.0
    private var netBottomY: CGFloat = 1.0

    // --- Net Crossing Detection ---
    private let sideHistoryLength = 5
    private var crossingStartFrame: Int = 0

    // --- Frame and Analysis State ---
    private var frameCount = 0
    private let frameSkip = 1
    private var ballHeightAtCrossing: CGFloat = 0.0

    // --- Scoring Logic Methods ---
    public func processBallNetCrossing(ballPosition: CGRect) {
        guard let netBox = netBox else { return }
        let netLineX = netBox.minX
        let ballCenterX = ballPosition.midX
        let side = ballCenterX < netLineX ? "left" : "right"
        if let lastSide = lastBallSide, lastSide == "left", side == "right" {
            totalAttempts += 1
            if ballPosition.midY >= netBox.minY && ballPosition.midY <= netBox.maxY {
                handleFailedShot(reason: "hit the net")
            } else if ballPosition.midY < netBox.minY {
                handleFailedShot(reason: "went under the net")
            } else {
                handleSuccessfulShot()
            }
            lastBallSide = side
            return
        }
        lastBallSide = side
    }

    private func handleFailedShot(reason: String) {
        failedShots += 1
    }

    private func handleSuccessfulShot() {
        successfulShots += 1
    }

    // --- Net Crossing Analysis Methods ---
    public func analyzeNetCrossing(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        guard ballTrajectory.count >= 3 else { return .uncertain }
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let netCenterX = netPosition.midX
        let currentSide = ballCenter.x < netCenterX ? "left" : "right"
        // Use BallTracker's mutator
        ballTracker.appendBallSideHistory(currentSide)
        if ballTracker.ballSideHistory.count > sideHistoryLength {
            ballTracker.removeFirstBallSideHistory()
        }
        if ballTracker.ballSideHistory.count >= sideHistoryLength {
            let hasLeftSide = ballTracker.ballSideHistory.contains("left")
            let hasRightSide = ballTracker.ballSideHistory.contains("right")
            if hasLeftSide && hasRightSide && !ballTracker.crossingInProgress {
                return initiateCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
            }
        }
        if ballTracker.crossingInProgress {
            return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
        }
        return .uncertain
    }

    private func initiateCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        ballTracker.setCrossingInProgress(true)
        crossingStartFrame = frameCount
        ballHeightAtCrossing = ballPosition.midY
        return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
    }

    private func continueCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        let ballCenterX = ballPosition.midX
        let netCenterX = netPosition.midX
        if ballCenterX > netCenterX + (netPosition.width * 0.3) {
            ballTracker.setCrossingInProgress(false)
            let crossingHeight = estimateCrossingHeight()
            let netMargin: CGFloat = 0.01
            if crossingHeight < netTopY - netMargin && validateSuccessfulTrajectory() {
                return .success_over_net
            } else if crossingHeight > netBottomY + 0.02 {
                return .failed_under_net
            } else if crossingHeight >= netTopY - 0.02 && crossingHeight <= netBottomY + 0.02 {
                return .failed_hit_net
            }
        }
        return .uncertain
    }

    private func estimateCrossingHeight() -> CGFloat {
        guard ballTrajectory.count >= 3 else { return ballHeightAtCrossing }
        guard let netPos = confirmedNetPosition else { return ballHeightAtCrossing }
        let netX = netPos.midX
        var closestPoints: [BallPosition] = []
        for position in ballTrajectory.suffix(8) {
            if abs(position.center.x - netX) < 0.1 {
                closestPoints.append(position)
            }
        }
        if !closestPoints.isEmpty {
            let avgHeight = closestPoints.map { $0.center.y }.reduce(0, +) / CGFloat(closestPoints.count)
            return avgHeight
        }
        if ballTrajectory.count >= 2 {
            let recent = ballTrajectory.suffix(2)
            let p1 = recent.first!
            let p2 = recent.last!
            if p2.center.x != p1.center.x {
                let slope = (p2.center.y - p1.center.y) / (p2.center.x - p1.center.x)
                let interpolatedY = p1.center.y + slope * (netX - p1.center.x)
                return interpolatedY
            }
        }
        return ballHeightAtCrossing
    }

    public func inferCrossingFromLostBall() -> NetCrossingResult {
        guard let lastPosition = ballTrajectory.last,
              let netPos = confirmedNetPosition else { return .uncertain }
        if ballVelocity.x > 0 && lastPosition.center.x > netPos.midX {
            let estimatedHeight = estimateCrossingHeight()
            if estimatedHeight < netTopY - 0.02 {
                return .success_over_net
            } else if estimatedHeight > netBottomY + 0.02 {
                return .failed_under_net
            } else {
                return .failed_hit_net
            }
        }
        return .uncertain
    }

    private func validateSuccessfulTrajectory() -> Bool {
        guard ballTrajectory.count >= 5 else { return false }
        let recent = ballTrajectory.suffix(5)
        let dxs = recent.dropFirst().enumerated().map { i, pos in
            pos.center.x - recent[i].center.x
        }
        let avgDx = dxs.reduce(0, +) / CGFloat(dxs.count)
        guard avgDx > 0.005 else { return false }
        let dys = recent.dropFirst().enumerated().map { i, pos in
            abs(pos.center.y - recent[i].center.y)
        }
        let maxDy = dys.max() ?? 0
        return maxDy < 0.08
    }

}
