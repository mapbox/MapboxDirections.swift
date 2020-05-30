import XCTest
import MapboxDirections
import CoreLocation
@testable import MapboxDirections

class WalkingOptionsTests: XCTestCase {
    func testURLQueryParams() {
        let waypoints = [
            RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 1)),
            RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 3))
        ]

        let options = RouteOptions(waypoints: waypoints, profileIdentifier: DirectionsProfileIdentifier.walking)
        var queryItems = options.urlQueryItems

        XCTAssertEqual(queryItems.first { $0.name == "alley_bias" }?.value, "0.0")
        XCTAssertEqual(queryItems.first { $0.name == "walkway_bias" }?.value, "0.0")
        XCTAssertEqual(queryItems.first { $0.name == "walking_speed" }?.value, "1.42")
        
        options.alleyPriority = DirectionsPriority(rawValue: 0.4)
        options.walkwayPriority = DirectionsPriority(rawValue: 0.5)
        options.speed = 5.2

        queryItems = options.urlQueryItems

        XCTAssertEqual(queryItems.first { $0.name == "alley_bias" }?.value, "0.4")
        XCTAssertEqual(queryItems.first { $0.name == "walkway_bias" }?.value, "0.5")
        XCTAssertEqual(queryItems.first { $0.name == "walking_speed" }?.value, "5.2")
    }
}
