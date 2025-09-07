import Foundation

class ScoringSystem {
    private var lastBallSide: String? = nil // "left" or "right"
    
    private func processBallNetCrossing(ballPosition: CGRect) {
        guard let netBox = netBox else { return }
        let netLineX = netBox.minX // Use left edge of net as the crossing line
        let ballCenterX = ballPosition.midX
        let side = ballCenterX < netLineX ? "left" : "right"
        if let lastSide = lastBallSide, lastSide == "left", side == "right" {
            // Ball crossed from left to right (player to net)
            DispatchQueue.main.async {
                self.totalAttempts += 1
            }
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
        DispatchQueue.main.async {
            self.failedShots += 1
            self.currentStatus = "Shot failed - \(reason)"
        }
    }
    
    private func handleSuccessfulShot() {
        DispatchQueue.main.async {
            self.successfulShots += 1
            self.currentStatus = "Shot successful!"
        }
    }
    
    private func analyzeNetCrossing(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        guard ballTrajectory.count >= 3 else { return .uncertain }
        
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let netCenterX = netPosition.midX
        
        // Determine which side of net the ball is on
        let currentSide = ballCenter.x < netCenterX ? "left" : "right"
        ballSideHistory.append(currentSide)
        
        // Keep only recent side history
        if ballSideHistory.count > sideHistoryLength {
            ballSideHistory.removeFirst()
        }
        
        // Check for crossing pattern (left to right typically for tennis)
        if ballSideHistory.count >= sideHistoryLength {
            let hasLeftSide = ballSideHistory.contains("left")
            let hasRightSide = ballSideHistory.contains("right")
            
            // Look for transition from left to right
            if hasLeftSide && hasRightSide && !crossingInProgress {
                return initiateCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
            }
        }
        
        // If crossing is in progress, continue monitoring
        if crossingInProgress {
            return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
        }
        
        return .uncertain
    }
    
    private func initiateCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        crossingInProgress = true
        crossingStartFrame = frameCount
        ballHeightAtCrossing = ballPosition.midY
        
        return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
    }
    
    private func continueCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        let ballCenterX = ballPosition.midX
        let netCenterX = netPosition.midX
        
        // Check if ball has clearly crossed to the right side
        if ballCenterX > netCenterX + (netPosition.width * 0.3) {
            crossingInProgress = false
            
            // Analyze trajectory at crossing point
            let crossingHeight = estimateCrossingHeight()
            
            // Determine result based on height relative to net
            let netMargin: CGFloat = 0.01 // Tighter margin
            if crossingHeight < netTopY - netMargin && validateSuccessfulTrajectory() {
                return .success_over_net
            } else if crossingHeight > netBottomY + 0.02 {  // Ball went clearly below net
                return .failed_under_net
            } else if crossingHeight >= netTopY - 0.02 && crossingHeight <= netBottomY + 0.02 {
                // Ball height is within net bounds - likely hit the net
                return .failed_hit_net
            }
        }
        
        return .uncertain
    }
    
    private func estimateCrossingHeight() -> CGFloat {
        guard ballTrajectory.count >= 3 else { return ballHeightAtCrossing }
        
        // Find the trajectory points closest to the net crossing
        guard let netPos = confirmedNetPosition else { return ballHeightAtCrossing }
        let netX = netPos.midX
        
        var closestPoints: [BallPosition] = []
        for position in ballTrajectory.suffix(8) {  // Look at recent positions
            if abs(position.center.x - netX) < 0.1 {  // Points near the net
                closestPoints.append(position)
            }
        }
        
        if !closestPoints.isEmpty {
            // Average the heights of points near the net
            let avgHeight = closestPoints.map { $0.center.y }.reduce(0, +) / CGFloat(closestPoints.count)
            return avgHeight
        }
        
        // Fallback: interpolate based on trajectory
        if ballTrajectory.count >= 2 {
            let recent = ballTrajectory.suffix(2)
            let p1 = recent.first!
            let p2 = recent.last!
            
            // Linear interpolation to estimate height at net X position
            if p2.center.x != p1.center.x {
                let slope = (p2.center.y - p1.center.y) / (p2.center.x - p1.center.x)
                let interpolatedY = p1.center.y + slope * (netX - p1.center.x)
                return interpolatedY
            }
        }
        
        return ballHeightAtCrossing
    }
    
    private func inferCrossingFromLostBall() -> NetCrossingResult {
        guard let lastPosition = ballTrajectory.last,
              let netPos = confirmedNetPosition else { return .uncertain }
        
        // If ball was moving toward net and then lost, infer based on last known trajectory
        if ballVelocity.x > 0 && lastPosition.center.x > netPos.midX {
            // Ball was crossing when lost
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
    
    // Validate that the ball's trajectory is smooth and consistent before and after net crossing
    private func validateSuccessfulTrajectory() -> Bool {
        // Require at least 5 trajectory points
        guard ballTrajectory.count >= 5 else { return false }
        // Check that the ball is moving mostly in the positive X direction (rightwards)
        let recent = ballTrajectory.suffix(5)
        let dxs = recent.dropFirst().enumerated().map { i, pos in
            pos.center.x - recent[i].center.x
        }
        let avgDx = dxs.reduce(0, +) / CGFloat(dxs.count)
        // Require average dx to be positive and above a small threshold
        guard avgDx > 0.005 else { return false }
        // Check that the Y values do not fluctuate wildly (no big bounces or drops)
        let dys = recent.dropFirst().enumerated().map { i, pos in
            abs(pos.center.y - recent[i].center.y)
        }
        let maxDy = dys.max() ?? 0
        // Require max dy to be within a reasonable range
        return maxDy < 0.08
    }
}
