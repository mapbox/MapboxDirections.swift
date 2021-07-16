import Foundation
import Turf

/**
 A `Route` object defines a single route that the user can follow to visit a series of waypoints in order. The route object includes information about the route, such as its distance and expected travel time. Depending on the criteria used to calculate the route, the route object may also include detailed turn-by-turn instructions.
 
 Typically, you do not create instances of this class directly. Instead, you receive route objects when you request directions using the `Directions.calculate(_:completionHandler:)` or `Directions.calculateRoutes(matching:completionHandler:)` method. However, if you use the `Directions.url(forCalculating:)` method instead, you can use `JSONDecoder` to convert the HTTP response into a `RouteResponse` or `MapMatchingResponse` object and access the `RouteResponse.routes` or `MapMatchingResponse.routes` property.
 */
open class Route: DirectionsResult {
    
    /**
     Initializes a route.
     
     - parameter legs: The legs that are traversed in order.
     - parameter shape: The roads or paths taken as a contiguous polyline.
     - parameter distance: The route’s distance, measured in meters.
     - parameter expectedTravelTime: The route’s expected travel time, measured in seconds.
     - parameter typicalTravelTime: The route’s typical travel time, measured in seconds.
     */
    public override init(legs: [RouteLeg], shape: LineString?, distance: LocationDistance, expectedTravelTime: TimeInterval, typicalTravelTime: TimeInterval? = nil) {
        super.init(legs: legs, shape: shape, distance: distance, expectedTravelTime: expectedTravelTime, typicalTravelTime: typicalTravelTime)
    }
    
    /**
     Initializes a route from a decoder.
     
     - precondition: If the decoder is decoding JSON data from an API response, the `Decoder.userInfo` dictionary must contain a `RouteOptions` or `MatchOptions` object in the `CodingUserInfoKey.options` key. If it does not, a `DirectionsCodingError.missingOptions` error is thrown.
     - parameter decoder: The decoder of JSON-formatted API response data or a previously encoded `Route` object.
     */
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}

extension Route: Equatable {
    public static func ==(lhs: Route, rhs: Route) -> Bool {
        return lhs.distance == rhs.distance &&
            lhs.expectedTravelTime == rhs.expectedTravelTime &&
            lhs.typicalTravelTime == rhs.typicalTravelTime &&
            lhs.speechLocale == rhs.speechLocale &&
            lhs.responseContainsSpeechLocale == rhs.responseContainsSpeechLocale &&
            lhs.legs == rhs.legs &&
            lhs.shape == rhs.shape
    }
}
