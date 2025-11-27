import Foundation

/// Represents the result of a ball crossing the net
enum NetCrossingResult {
    case success_over_net
    case failed_hit_net
    case failed_under_net
    case uncertain
}
