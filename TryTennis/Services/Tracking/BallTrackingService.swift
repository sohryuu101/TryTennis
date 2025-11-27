import Foundation

/// Service for tracking ball trajectory and state during gameplay
class BallTrackingService {
    // MARK: - Properties
    private var _ballTrajectory: [BallPosition] = []
    public var ballTrajectory: [BallPosition] { _ballTrajectory }
    private let maxTrajectoryLength = 10
    private var consecutiveFramesWithBall = 0

    private var velocityHistory: [CGPoint] = []
    private let velocityHistoryLength = 5
    public private(set) var ballVelocity: CGPoint = .zero
    public private(set) var lastBallVelocity: CGPoint = .zero

    public private(set) var confirmedNetPosition: CGRect?
    private var netPositions: [CGRect] = []
    private let maxNetVariance: CGFloat = 0.05

    public private(set) var lastBallState: BallState = .unknown
    public private(set) var crossingInProgress = false
    public private(set) var ballSideHistory: [String] = []
    
    // MARK: - Public Methods
    
    /// Update ball trajectory with a new position
    public func updateBallTrajectory(ballPosition: CGRect, frameCount: Int) {
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let ballPos = BallPosition(center: ballCenter, timestamp: timestamp, frame: frameCount)
        _ballTrajectory.append(ballPos)
        
        if _ballTrajectory.count > maxTrajectoryLength {
            _ballTrajectory.removeFirst()
        }
        
        calculateSmoothedVelocity()
        consecutiveFramesWithBall += 1
        updateBallState(ballCenter: ballCenter)
    }
    
    /// Update net position
    public func updateNetPosition(_ netRect: CGRect) {
        if validateNetPosition(netRect) {
            netPositions.append(netRect)
            if netPositions.count > 10 {
                netPositions.removeFirst()
            }
            confirmedNetPosition = calculateStableNetPosition()
        }
    }
    
    /// Handle when ball is lost
    public func handleBallLost() {
        consecutiveFramesWithBall = 0
        
        if ballTrajectory.count > 0 &&
           CFAbsoluteTimeGetCurrent() - ballTrajectory.last!.timestamp > 1.0 {
            _ballTrajectory.removeAll()
            ballSideHistory.removeAll()
            crossingInProgress = false
        }
    }
    
    /// Add side to history
    public func appendBallSideHistory(_ side: String) {
        ballSideHistory.append(side)
    }
    
    /// Remove first from history
    public func removeFirstBallSideHistory() {
        if !ballSideHistory.isEmpty {
            ballSideHistory.removeFirst()
        }
    }
    
    /// Reset ball side history
    public func resetBallSideHistory() {
        ballSideHistory.removeAll()
    }
    
    /// Set crossing in progress
    public func setCrossingInProgress(_ value: Bool) {
        crossingInProgress = value
    }
    
    /// Reset ball velocity history
    public func resetBallVelocityHistory() {
        velocityHistory.removeAll()
    }
    
    /// Reset ball trajectory
    public func resetBallTrajectory() {
        _ballTrajectory.removeAll()
    }
    
    /// Reset all tracking data
    public func resetAllTracking() {
        resetBallSideHistory()
        resetBallVelocityHistory()
        resetBallTrajectory()
        netPositions.removeAll()
        confirmedNetPosition = nil
        crossingInProgress = false
        ballVelocity = .zero
        lastBallVelocity = .zero
        lastBallState = .unknown
        consecutiveFramesWithBall = 0
    }
    
    // MARK: - Private Methods
    
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
        let isMovingTowardNet = ballVelocity.x > 0
        
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
    
    private func validateNetPosition(_ netRect: CGRect) -> Bool {
        if netPositions.isEmpty {
            return true
        }
        
        let recentPositions = netPositions.suffix(5)
        let avgX = recentPositions.map { $0.midX }.reduce(0, +) / CGFloat(recentPositions.count)
        let avgY = recentPositions.map { $0.midY }.reduce(0, +) / CGFloat(recentPositions.count)
        
        let variance = sqrt(pow(netRect.midX - avgX, 2) + pow(netRect.midY - avgY, 2))
        return variance < maxNetVariance
    }
    
    private func calculateStableNetPosition() -> CGRect? {
        guard !netPositions.isEmpty else { return nil }
        
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
