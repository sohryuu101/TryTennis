import Foundation

class BallTracker {
    
    private func updateBallTrajectory(ballPosition: CGRect, frameCount: Int) {
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let ballPos = BallPosition(center: ballCenter, timestamp: timestamp, frame: frameCount)
        ballTrajectory.append(ballPos)
        
        // Keep only recent trajectory points
        if ballTrajectory.count > maxTrajectoryLength {
            ballTrajectory.removeFirst()
        }
        
        // Calculate smoothed velocity
        calculateSmoothedVelocity()
        
        consecutiveFramesWithBall += 1
        
        // Update ball state based on trajectory
        updateBallState(ballCenter: ballCenter)
    }
    
    // Enhanced velocity calculation with smoothing
    private func calculateSmoothedVelocity() {
        guard ballTrajectory.count >= 2 else { return }
        
        let current = ballTrajectory.last!
        let previous = ballTrajectory[ballTrajectory.count - 2]
        
        let timeDiff = current.timestamp - previous.timestamp
        if timeDiff > 0 {
            let instantVelocity = CGPoint(
                x: (current.center.x - previous.center.x) / CGFloat(timeDiff),
                y: (current.center.y - previous.center.y) / CGFloat(timeDiff)
            )
            
            velocityHistory.append(instantVelocity)
            if velocityHistory.count > velocityHistoryLength {
                velocityHistory.removeFirst()
            }
            
            // Calculate smoothed velocity
            if !velocityHistory.isEmpty {
                let avgVelX = velocityHistory.map { $0.x }.reduce(0, +) / CGFloat(velocityHistory.count)
                let avgVelY = velocityHistory.map { $0.y }.reduce(0, +) / CGFloat(velocityHistory.count)
                
                lastBallVelocity = ballVelocity
                ballVelocity = CGPoint(x: avgVelX, y: avgVelY)
            }
        }
    }
    
    private func updateBallState(ballCenter: CGPoint) {
        guard let netPos = confirmedNetPosition else {
            lastBallState = .detected
            return
        }
        
        let distanceToNet = abs(ballCenter.x - netPos.midX)
        let isMovingTowardNet = ballVelocity.x > 0 // Assuming net is on the right
        
        if distanceToNet < 0.15 && isMovingTowardNet {
            lastBallState = .approaching_net
        } else if distanceToNet < 0.05 {
            lastBallState = .crossing_net
        } else if ballCenter.x > netPos.midX + 0.1 {
            lastBallState = .crossed_net
        } else {
            lastBallState = .detected
        }
    }
    
    private func handleBallLost() {
        consecutiveFramesWithBall = 0
        
        // If ball was lost during crossing, try to infer result from trajectory
        if crossingInProgress && ballTrajectory.count >= 3 {
            let result = inferCrossingFromLostBall()
            if result != .uncertain {
                processCrossingResult(result)
            }
        }
        
        // Clear old trajectory if ball has been lost for too long
        if ballTrajectory.count > 0 &&
           CFAbsoluteTimeGetCurrent() - ballTrajectory.last!.timestamp > 1.0 {
            ballTrajectory.removeAll()
            ballSideHistory.removeAll()
            crossingInProgress = false
        }
    }
    
    // Validate net position consistency
    private func validateNetPosition(_ netRect: CGRect) -> Bool {
        if netPositions.isEmpty {
            return true
        }
        
        // Check if new position is consistent with previous detections
        let recentPositions = netPositions.suffix(5)
        let avgX = recentPositions.map { $0.midX }.reduce(0, +) / CGFloat(recentPositions.count)
        let avgY = recentPositions.map { $0.midY }.reduce(0, +) / CGFloat(recentPositions.count)
        
        let variance = sqrt(pow(netRect.midX - avgX, 2) + pow(netRect.midY - avgY, 2))
        return variance < maxNetVariance
    }
    
    private func calculateStableNetPosition() -> CGRect? {
        guard !netPositions.isEmpty else { return nil }
        
        // Calculate average position for stability
        let avgX = netPositions.map { $0.midX }.reduce(0, +) / CGFloat(netPositions.count)
        let avgY = netPositions.map { $0.midY }.reduce(0, +) / CGFloat(netPositions.count)
        let avgWidth = netPositions.map { $0.width }.reduce(0, +) / CGFloat(netPositions.count)
        let avgHeight = netPositions.map { $0.height }.reduce(0, +) / CGFloat(netPositions.count)
        
        return CGRect(
            x: avgX - avgWidth/2,
            y: avgY - avgHeight/2,
            width: avgWidth,
            height: avgHeight
        )
    }
}
