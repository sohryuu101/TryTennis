import Foundation

/// Represents the current state of the ball during tracking
enum BallState {
    case unknown
    case detected
    case approaching_net
    case crossing_net
    case crossed_net
    case lost
}
