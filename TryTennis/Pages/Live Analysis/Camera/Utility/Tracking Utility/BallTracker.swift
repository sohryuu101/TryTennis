import Foundation

protocol BallTrackerDelegate: AnyObject {
    func ballTracker(_ tracker: BallTracker, didProcessCrossingResult result: NetCrossingResult)
}

class BallTracker {
    // -- Ball Trajectory --
    private var _ballTrajectory: [BallPosition] = []
    public var ballTrajectory: [BallPosition] { _ballTrajectory }
    private let maxTrajectoryLength = 10 // Track last 10 positions
    private var consecutiveFramesWithBall = 0

    // -- Velocity Smoothing --
    private var velocityHistory: [CGPoint] = []
    private let velocityHistoryLength = 5
    public private(set) var ballVelocity: CGPoint = .zero
    public private(set) var lastBallVelocity: CGPoint = .zero

    // -- Net Position --
    public private(set) var confirmedNetPosition: CGRect?
    private var netPositions: [CGRect] = []
    private let maxNetVariance: CGFloat = 0.05  // Maximum allowed variance in net position

    // -- Ball State --
    public private(set) var lastBallState: BallState = .unknown
    public private(set) var crossingInProgress = false
    public private(set) var ballSideHistory: [String] = []

    // -- Dependency Injection --
    var scoringSystem: ScoringSystem!

    // -- Delegate --
    weak var delegate: BallTrackerDelegate?
    
    init() {
        self.scoringSystem = ScoringSystem(ballTracker: self)
    }
    
    private func updateBallTrajectory(ballPosition: CGRect, frameCount: Int) {
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let ballPos = BallPosition(center: ballCenter, timestamp: timestamp, frame: frameCount)
        _ballTrajectory.append(ballPos)
        
        // Keep only recent trajectory points
        if _ballTrajectory.count > maxTrajectoryLength {
            _ballTrajectory.removeFirst()
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
            let result = scoringSystem.inferCrossingFromLostBall()
            if result != .uncertain {
                delegate?.ballTracker(self, didProcessCrossingResult: result)
            }
        }
        
        // Clear old trajectory if ball has been lost for too long
        if ballTrajectory.count > 0 &&
           CFAbsoluteTimeGetCurrent() - ballTrajectory.last!.timestamp > 1.0 {
            _ballTrajectory.removeAll()
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
    
    // --- Ball Side History Mutators ---
    public func appendBallSideHistory(_ side: String) {
        ballSideHistory.append(side)
    }
    public func removeFirstBallSideHistory() {
        if !ballSideHistory.isEmpty {
            ballSideHistory.removeFirst()
        }
    }
    public func resetBallSideHistory() {
        ballSideHistory.removeAll()
    }
    // --- Crossing In Progress Mutator ---
    public func setCrossingInProgress(_ value: Bool) {
        crossingInProgress = value
    }
    
    public func resetBallVelocityHistory() {
        velocityHistory.removeAll()
    }
    
    public func resetBallTrajectory() {
        _ballTrajectory.removeAll()
    }
    
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
}
