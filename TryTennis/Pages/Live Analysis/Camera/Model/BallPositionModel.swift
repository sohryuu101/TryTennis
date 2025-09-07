import Foundation

struct BallPosition {
    let center: CGPoint
    let timestamp: CFTimeInterval
    let frame: Int
    
}

enum BallState {
    case unknown
    case detected
    case approaching_net
    case crossing_net
    case crossed_net
    case lost
}

enum NetCrossingResult {
    case success_over_net
    case failed_hit_net
    case failed_under_net
    case uncertain
}

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
