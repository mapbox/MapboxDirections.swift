import Foundation
import CoreLocation
import Polyline
import struct Turf.LineString

/**
 A `Weight` enum represents the weight given to a specific match by the Directions API. The default metric is a compound index called "routability",  which is duration-based with additional penalties for less desirable maneuvers.
 */
public enum Weight: Equatable {
    
    case routability(value: Float)
    case other(value: Float, metric: String)
    
    public init(value: Float, metric: String) {
        switch metric {
        case "routability":
            self = .routability(value: value)
        default:
            self = .other(value: value, metric: metric)
        }
    }
    
    var metric: String {
        switch self {
        case .routability(value: _):
            return "routability"
        case let .other(value: _, metric: value):
            return value
        }
    }
    
    var value: Float {
        switch self {
        case let .routability(value: weight):
            return weight
        case let .other(value: weight, metric: _):
            return weight
        }
    }
}

/**
 A `Match` object defines a single route that was created from a series of points that were matched against a road network.
 
 Typically, you do not create instances of this class directly. Instead, you receive match objects when you pass a `MatchOptions` object into the `Directions.calculate(_:completionHandler:)` method.
 */
open class Match: DirectionsResult {
    private enum CodingKeys: String, CodingKey {
        case confidence
        case tracepoints
        case weight
        case weightName = "weight_name"
    }
    
    /**
     Initializes a match.
     
     Typically, you do not create instances of this class directly. Instead, you receive match objects when you request matches using the `Directions.calculate(_:completionHandler:)` method.
     
     - parameter legs: The legs that are traversed in order.
     - parameter shape: The matching roads or paths as a contiguous polyline.
     - parameter distance: The matched path’s cumulative distance, measured in meters.
     - parameter expectedTravelTime: The route’s expected travel time, measured in seconds.
     - parameter confidence: A number between 0 and 1 that indicates the Map Matching API’s confidence that the match is accurate. A higher confidence means the match is more likely to be accurate.
     - parameter tracepoints: Tracepoints on the road network that match the tracepoints in options.
     - parameter weight:  A `Weight` used to determine units and weight type used for matching
     */
    public init(legs: [RouteLeg], shape: LineString?, distance: CLLocationDistance, expectedTravelTime: TimeInterval, confidence: Float, tracepoints: [Tracepoint?], weight: Weight) {
        self.confidence = confidence
        self.tracepoints = tracepoints
        self.weight = weight
        super.init(legs: legs, shape: shape, distance: distance, expectedTravelTime: expectedTravelTime)
    }
    
    /**
     Creates a match from a decoder.
     
     - precondition: If the decoder is decoding JSON data from an API response, the `Decoder.userInfo` dictionary must contain a `MatchOptions` object in the `CodingUserInfoKey.options` key. If it does not, a `DirectionsCodingError.missingOptions` error is thrown.
     - parameter decoder: The decoder of JSON-formatted API response data or a previously encoded `Match` object.
     */
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confidence = try container.decode(Float.self, forKey: .confidence)
        tracepoints = try container.decodeIfPresent([Tracepoint?].self, forKey: .tracepoints) ?? []
        let weightValue = try container.decode(Float.self, forKey: .weight)
        let weightMetric = try container.decode(String.self, forKey: .weightName)
        
        weight = Weight(value: weightValue, metric: weightMetric)
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(tracepoints, forKey: .tracepoints)
        try container.encode(weight.value, forKey: .weight)
        try container.encode(weight.metric, forKey: .weightName)
        
        try super.encode(to: encoder)
    }
    
    open var weight: Weight
    
    /**
     A number between 0 and 1 that indicates the Map Matching API’s confidence that the match is accurate. A higher confidence means the match is more likely to be accurate.
     */
    open var confidence: Float
    
    /**
     Tracepoints on the road network that match the tracepoints in the match options.
     
     Any outlier tracepoint is omitted from the match. This array represents an outlier tracepoint if the element is `nil`.
     */
    open var tracepoints: [Tracepoint?]
}

extension Match: Equatable {
    public static func ==(lhs: Match, rhs: Match) -> Bool {
        return lhs.routeIdentifier == rhs.routeIdentifier &&
            lhs.distance == rhs.distance &&
            lhs.expectedTravelTime == rhs.expectedTravelTime &&
            lhs.speechLocale == rhs.speechLocale &&
            lhs.confidence == rhs.confidence &&
            lhs.tracepoints == rhs.tracepoints &&
            lhs.weight == rhs.weight &&
            lhs.legs == rhs.legs &&
            lhs.shape == rhs.shape
    }
}
