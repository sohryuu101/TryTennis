import Foundation

/// Service for managing game scoring and shot analysis
class ScoringService {
    // MARK: - Properties
    private var totalAttempts: Int = 0
    private var successfulShots: Int = 0
    private var failedShots: Int = 0
    
    private var ballTrackingService: BallTrackingService
    
    private var lastBallSide: String? = nil
    private var netBox: CGRect? = nil
    private var netTopY: CGFloat = 0.0
    private var netBottomY: CGFloat = 1.0
    
    private let sideHistoryLength = 5
    private var crossingStartFrame: Int = 0
    private var ballHeightAtCrossing: CGFloat = 0.0
    
    private var frameCount: Int = 0
    
    // MARK: - Initialization
    init(ballTrackingService: BallTrackingService) {
        self.ballTrackingService = ballTrackingService
    }
    
    // MARK: - Public Methods
    
    func setFrameCount(_ count: Int) {
        self.frameCount = count
    }
    
    func getStatistics() -> (total: Int, successful: Int, failed: Int) {
        return (totalAttempts, successfulShots, failedShots)
    }
    
    func incrementSuccessful() {
        successfulShots += 1
        totalAttempts += 1
    }
    
    func incrementFailed() {
        failedShots += 1
        totalAttempts += 1
    }
    
    func resetStatistics() {
        totalAttempts = 0
        successfulShots = 0
        failedShots = 0
    }
    
    /// Analyze net crossing and return result
    func analyzeNetCrossing(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        guard ballTrackingService.ballTrajectory.count >= 3 else { return .uncertain }
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let netCenterX = netPosition.midX
        let currentSide = ballCenter.x < netCenterX ? "left" : "right"
        
        ballTrackingService.appendBallSideHistory(currentSide)
        if ballTrackingService.ballSideHistory.count > sideHistoryLength {
            ballTrackingService.removeFirstBallSideHistory()
        }
        
        if ballTrackingService.ballSideHistory.count >= sideHistoryLength {
            let hasLeftSide = ballTrackingService.ballSideHistory.contains("left")
            let hasRightSide = ballTrackingService.ballSideHistory.contains("right")
            if hasLeftSide && hasRightSide && !ballTrackingService.crossingInProgress {
                return initiateCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
            }
        }
        
        if ballTrackingService.crossingInProgress {
            return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
        }
        return .uncertain
    }
    
    /// Infer crossing result when ball is lost
    func inferCrossingFromLostBall() -> NetCrossingResult {
        guard let lastPosition = ballTrackingService.ballTrajectory.last,
              let netPos = ballTrackingService.confirmedNetPosition else { return .uncertain }
        if ballTrackingService.ballVelocity.x > 0 && lastPosition.center.x > netPos.midX {
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
    
    // MARK: - Private Methods
    
    private func initiateCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        ballTrackingService.setCrossingInProgress(true)
        crossingStartFrame = frameCount
        ballHeightAtCrossing = ballPosition.midY
        return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
    }
    
    private func continueCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        let ballCenterX = ballPosition.midX
        let netCenterX = netPosition.midX
        if ballCenterX > netCenterX + (netPosition.width * 0.3) {
            ballTrackingService.setCrossingInProgress(false)
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
        guard ballTrackingService.ballTrajectory.count >= 3 else { return ballHeightAtCrossing }
        guard let netPos = ballTrackingService.confirmedNetPosition else { return ballHeightAtCrossing }
        let netX = netPos.midX
        var closestPoints: [BallPosition] = []
        for position in ballTrackingService.ballTrajectory.suffix(8) {
            if abs(position.center.x - netX) < 0.1 {
                closestPoints.append(position)
            }
        }
        if !closestPoints.isEmpty {
            let avgHeight = closestPoints.map { $0.center.y }.reduce(0, +) / CGFloat(closestPoints.count)
            return avgHeight
        }
        if ballTrackingService.ballTrajectory.count >= 2 {
            let recent = ballTrackingService.ballTrajectory.suffix(2)
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
    
    private func validateSuccessfulTrajectory() -> Bool {
        guard ballTrackingService.ballTrajectory.count >= 5 else { return false }
        let recent = ballTrackingService.ballTrajectory.suffix(5)
        let dxs = recent.dropFirst().enumerated().map { i, pos in
            pos.center.x - recent[recent.startIndex + i].center.x
        }
        let avgDx = dxs.reduce(0, +) / CGFloat(dxs.count)
        guard avgDx > 0.005 else { return false }
        let dys = recent.dropFirst().enumerated().map { i, pos in
            abs(pos.center.y - recent[recent.startIndex + i].center.y)
        }
        let maxDy = dys.max() ?? 0
        return maxDy < 0.08
    }
}
