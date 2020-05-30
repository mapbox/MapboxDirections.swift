import XCTest
@testable import MapboxDirections

class RouteTests: XCTestCase {
    func testCoding() {
        // https://api.mapbox.com/directions/v5/mapbox/driving-traffic/-105.08198579860195%2C39.73843005470756;-104.954255,39.662569.json?overview=false&access_token=…
        let routeJSON: [String: Any?] = [
            "legs": [
                [
                    "summary": "West 6th Avenue Freeway, South University Boulevard",
                    "weight": 1346.3,
                    "duration": 1083.4,
                    "steps": [],
                    "distance": 17036.8,
                ],
            ],
            "weight_name": "routability",
            "weight": 1346.3,
            "duration": 1083.4,
            "distance": 17036.8,
        ]
        let routeData = try! JSONSerialization.data(withJSONObject: routeJSON, options: [])
        
        let options = RouteOptions(coordinates: [
            CLLocationCoordinate2D(latitude: 39.73843005470756, longitude: -105.08198579860195),
            CLLocationCoordinate2D(latitude: 39.662569, longitude: -104.954255),
        ], profileIdentifier: .automobileAvoidingTraffic)
        options.routeShapeResolution = .none
        
        let decoder = JSONDecoder()
        var route: Route?
        XCTAssertThrowsError(route = try decoder.decode(Route.self, from: routeData))
        decoder.userInfo[.options] = options
        XCTAssertNoThrow(route = try decoder.decode(Route.self, from: routeData))
        
        let expectedLeg = RouteLeg(steps: [], name: "West 6th Avenue Freeway, South University Boulevard", distance: 17036.8, expectedTravelTime: 1083.4, profileIdentifier: .automobileAvoidingTraffic)
        expectedLeg.source = Route.Waypoint(coordinate: options.waypoints[0].coordinate, correction: 0, name: options.waypoints[0].name)
        expectedLeg.destination = Route.Waypoint(coordinate: options.waypoints[1].coordinate, correction: 0, name: options.waypoints[1].name)
        let expectedRoute = Route(legs: [expectedLeg], shape: nil, distance: 17036.8, expectedTravelTime: 1083.4)
        XCTAssertEqual(route, expectedRoute)
        
        if let route = route {
            let encoder = JSONEncoder()
            encoder.userInfo[.options] = options
            var encodedRouteData: Data?
            XCTAssertNoThrow(encodedRouteData = try encoder.encode(route))
            XCTAssertNotNil(encodedRouteData)
            
            if let encodedRouteData = encodedRouteData {
                var encodedRouteJSON: [String: Any?]?
                XCTAssertNoThrow(encodedRouteJSON = try JSONSerialization.jsonObject(with: encodedRouteData, options: []) as? [String: Any?])
                XCTAssertNotNil(encodedRouteJSON)
                
                // Remove keys not found in the original API response.
                encodedRouteJSON?.removeValue(forKey: "source")
                encodedRouteJSON?.removeValue(forKey: "destination")
                encodedRouteJSON?.removeValue(forKey: "profileIdentifier")
                if var encodedLegJSON = encodedRouteJSON?["legs"] as? [[String: Any?]] {
                    encodedLegJSON[0].removeValue(forKey: "source")
                    encodedLegJSON[0].removeValue(forKey: "destination")
                    encodedLegJSON[0].removeValue(forKey: "profileIdentifier")
                    encodedRouteJSON?["legs"] = encodedLegJSON
                }

                // https://github.com/mapbox/mapbox-directions-swift/issues/125
                var referenceRouteJSON = routeJSON
                referenceRouteJSON.removeValue(forKey: "weight")
                referenceRouteJSON.removeValue(forKey: "weight_name")
                var referenceLegJSON = referenceRouteJSON["legs"] as! [[String: Any?]]
                referenceLegJSON[0].removeValue(forKey: "weight")
                referenceRouteJSON["legs"] = referenceLegJSON
                
                XCTAssert(JSONSerialization.objectsAreEqual(referenceRouteJSON, encodedRouteJSON, approximate: true))
            }
        }
    }
}
