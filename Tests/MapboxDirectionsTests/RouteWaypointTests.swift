import XCTest
import CoreLocation
@testable import MapboxDirections

class RouteWaypointTests: XCTestCase {
    func testCoding() {
        let waypointJSON: [String: Any?] = [
            "location": [-77.036500000000004, 38.8977],
            "name": "White House",
            "distance": 10.1
        ]
        let waypointData = try! JSONSerialization.data(withJSONObject: waypointJSON, options: [])
        var waypoint: Route.Waypoint?
        XCTAssertNoThrow(waypoint = try JSONDecoder().decode(Route.Waypoint.self, from: waypointData))
        XCTAssertNotNil(waypoint)

        if let waypoint = waypoint {
            XCTAssertEqual(waypoint.coordinate.latitude, 38.8977, accuracy: 1e-5)
            XCTAssertEqual(waypoint.coordinate.longitude, -77.03650, accuracy: 1e-5)
            XCTAssertEqual(waypoint.name, "White House")
            XCTAssertEqual(waypoint.correction, 10.1)
        }

        waypoint = Route.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), correction: 10.1, name: "White House")

        let encoder = JSONEncoder()
        var encodedData: Data?
        XCTAssertNoThrow(encodedData = try encoder.encode(waypoint))
        XCTAssertNotNil(encodedData)

        if let encodedData = encodedData {
            var encodedWaypointJSON: [String: Any?]?
            XCTAssertNoThrow(encodedWaypointJSON = try JSONSerialization.jsonObject(with: encodedData, options: []) as? [String: Any?])
            XCTAssertNotNil(encodedWaypointJSON)

            let targetCoordinateJSON = encodedWaypointJSON?["location"] as? [CLLocationDegrees]
            XCTAssertNotNil(targetCoordinateJSON)
            XCTAssertEqual(targetCoordinateJSON?.count, 2)
            XCTAssertEqual(targetCoordinateJSON?[0] ?? 0, waypoint?.coordinate.longitude ?? 0, accuracy: 1e-5)
            XCTAssertEqual(targetCoordinateJSON?[1] ?? 0, waypoint?.coordinate.latitude ?? 0, accuracy: 1e-5)
            
            XCTAssertEqual(encodedWaypointJSON?["distance"] as? CLLocationDistance, waypoint?.correction)
            XCTAssertEqual(encodedWaypointJSON?["name"] as? String, waypoint?.name)
            
            
            XCTAssert(JSONSerialization.objectsAreEqual(waypointJSON, encodedWaypointJSON, approximate: true))
        }
    }
    
    func testEquality() {
        let left = Route.Waypoint(coordinate: CLLocationCoordinate2D(), correction: 0, name: nil)
        XCTAssertEqual(left, left)

        var right = Route.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1), correction: 0, name: nil)
        XCTAssertNotEqual(left, right)

        right = Route.Waypoint(coordinate: CLLocationCoordinate2D(), correction: 1, name: nil)
        XCTAssertNotEqual(left, right)

        right = Route.Waypoint(coordinate: CLLocationCoordinate2D(), correction: 0, name: "")
        XCTAssertNotEqual(left, right)
    }
}
