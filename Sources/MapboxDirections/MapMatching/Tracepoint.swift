import Foundation
import CoreLocation

public extension Match {
    /**
     A tracepoint represents a location matched to the road network.
     */
    struct Tracepoint: Matchpoint, Equatable {
        /**
         The geographic coordinate of the waypoint, snapped to the road network.
         */
        public var coordinate: CLLocationCoordinate2D
        
        /**
         The straight-line distance from this waypoint to the corresponding waypoint in the `RouteOptions` or `MatchOptions` object.
         
         The requested waypoint is snapped to the road network. This property contains the straight-line distance from the original requested waypoint’s `DirectionsOptions.Waypoint.coordinate` property to the `coordinate` property.
         */
        public var correction: CLLocationDistance
        
        /**
         Number of probable alternative matchings for this tracepoint. A value of zero indicates that this point was matched unambiguously.
         */
        public var countOfAlternatives: Int
        
        /**
         The name of the road or path the coordinate snapped to.
         */
        public var name: String?
        
        /***
         The index of the match object in matchings that the sub-trace was matched to.
         */
        public var matchingIndex: Int
        
        /***
         The index of the waypoint inside the matched route.
         */
        public var waypointIndex: Int
    }
}

extension Match.Tracepoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case coordinate = "location"
        case correction = "distance"
        case countOfAlternatives = "alternatives_count"
        case name
        case matchingIndex = "matchings_index"
        case waypointIndex = "waypoint_index"
    }
}

extension Match.Tracepoint: CustomStringConvertible {
    public var description: String {
        return "<latitude: \(coordinate.latitude); longitude: \(coordinate.longitude)>"
    }
}
