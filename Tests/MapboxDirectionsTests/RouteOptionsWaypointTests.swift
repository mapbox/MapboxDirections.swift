import XCTest
import CoreLocation
@testable import MapboxDirections

class RouteOptionsWaypointTests: XCTestCase {
    func testCoding() {
        let waypointJSON: [String: Any?] = [
            "location": [-77.036500000000004, 38.8977],
            "name": "White House",
        ]
        let waypointData = try! JSONSerialization.data(withJSONObject: waypointJSON, options: [])
        var waypoint: RouteOptions.Waypoint?
        XCTAssertNoThrow(waypoint = try JSONDecoder().decode(RouteOptions.Waypoint.self, from: waypointData))
        XCTAssertNotNil(waypoint)
        
        if let waypoint = waypoint {
            XCTAssertEqual(waypoint.coordinate.latitude, 38.8977, accuracy: 1e-5)
            XCTAssertEqual(waypoint.coordinate.longitude, -77.03650, accuracy: 1e-5)
            XCTAssertNil(waypoint.coordinateAccuracy)
            XCTAssertNil(waypoint.targetCoordinate)

            XCTAssertNil(waypoint.heading)
            XCTAssertNil(waypoint.headingAccuracy)
            XCTAssertTrue(waypoint.allowsArrivingOnOppositeSide)
            XCTAssertTrue(waypoint.separatesLegs)
        }
        
        waypoint = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), coordinateAccuracy: 5, name: "White House")
        waypoint?.targetCoordinate = CLLocationCoordinate2D(latitude: 38.8952261, longitude: -77.0327882)
        waypoint?.heading = 90
        waypoint?.headingAccuracy = 10
        waypoint?.allowsArrivingOnOppositeSide = false
        
        let encoder = JSONEncoder()
        var encodedData: Data?
        XCTAssertNoThrow(encodedData = try encoder.encode(waypoint))
        XCTAssertNotNil(encodedData)
        
        if let encodedData = encodedData {
            var encodedWaypointJSON: [String: Any?]?
            XCTAssertNoThrow(encodedWaypointJSON = try JSONSerialization.jsonObject(with: encodedData, options: []) as? [String: Any?])
            XCTAssertNotNil(encodedWaypointJSON)
            
            XCTAssertEqual(encodedWaypointJSON?["headingAccuracy"] as? CLLocationDirection, waypoint?.headingAccuracy)
            XCTAssertEqual(encodedWaypointJSON?["coordinateAccuracy"] as? CLLocationAccuracy, waypoint?.coordinateAccuracy)
            XCTAssertEqual(encodedWaypointJSON?["allowsArrivingOnOppositeSide"] as? Bool, waypoint?.allowsArrivingOnOppositeSide)
            XCTAssertEqual(encodedWaypointJSON?["heading"] as? CLLocationDirection, waypoint?.heading)
            XCTAssertEqual(encodedWaypointJSON?["separatesLegs"] as? Bool, waypoint?.separatesLegs)
           
            let targetCoordinateJSON = encodedWaypointJSON?["targetCoordinate"] as? [CLLocationDegrees]
            XCTAssertNotNil(targetCoordinateJSON)
            XCTAssertEqual(targetCoordinateJSON?.count, 2)
            XCTAssertEqual(targetCoordinateJSON?[0] ?? 0, waypoint?.targetCoordinate?.longitude ?? 0, accuracy: 1e-5)
            XCTAssertEqual(targetCoordinateJSON?[1] ?? 0, waypoint?.targetCoordinate?.latitude ?? 0, accuracy: 1e-5)
            
            let encodedWaypointData = try! JSONSerialization.data(withJSONObject: encodedWaypointJSON!, options: [])
            var decodedWaypoint: RouteOptions.Waypoint?
            
            XCTAssertNoThrow(decodedWaypoint = try JSONDecoder().decode(RouteOptions.Waypoint.self, from: encodedWaypointData))
            XCTAssertEqual(waypoint, decodedWaypoint)
        }
    }
    
    func testSeparatesLegs() {
        let one = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1))
        let two = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 2))
        let three = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 3, longitude: 3))
        let four = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 4, longitude: 4))
        
        let routeOptions = RouteOptions(waypoints: [one, two, three, four])
        let matchOptions = MatchOptions(waypoints: [one, two, three, four], profileIdentifier: nil)
        
        XCTAssertNil(routeOptions.urlQueryItems.first { $0.name == "waypoints" }?.value)
        XCTAssertNil(matchOptions.urlQueryItems.first { $0.name == "waypoints" }?.value)
        
        routeOptions.waypoints[1].separatesLegs = false
        matchOptions.waypoints[1].separatesLegs = false
        
        XCTAssertEqual(routeOptions.urlQueryItems.first { $0.name == "waypoints" }?.value, "0;2;3")
        XCTAssertEqual(matchOptions.urlQueryItems.first { $0.name == "waypoints" }?.value, "0;2;3")
        
        matchOptions.waypointIndices = [0, 2, 3]
        
        XCTAssertEqual(matchOptions.urlQueryItems.first { $0.name == "waypoints" }?.value, "0;2;3")
    }
    
    func testHeading() {
        var waypoint = RouteOptions.Waypoint(coordinate: kCLLocationCoordinate2DInvalid)
        XCTAssertEqual(waypoint.headingDescription, "")
        
        waypoint.heading = 0
        XCTAssertEqual(waypoint.headingDescription, "")
        
        waypoint.headingAccuracy = 0
        XCTAssertEqual(waypoint.headingDescription, "0.0,0.0")
        
        waypoint.heading = 810.5
        XCTAssertEqual(waypoint.headingDescription, "90.5,0.0")
        
        waypoint.headingAccuracy = 720
        XCTAssertEqual(waypoint.headingDescription, "90.5,180.0")
    }
    
    func testEquality() {
        let left = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(), coordinateAccuracy: nil, name: nil)
        XCTAssertEqual(left, left)
        
        var right = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1), coordinateAccuracy: nil, name: nil)
        XCTAssertNotEqual(left, right)
        
        right = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(), coordinateAccuracy: 0, name: nil)
        XCTAssertNotEqual(left, right)
        
        right = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(), coordinateAccuracy: nil, name: "")
        XCTAssertNotEqual(left, right)
    }
    
    func testTracepointEquality() {
        let left = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 0, countOfAlternatives: 0, name: nil, matchingIndex: 0, waypointIndex: 0)
        XCTAssertEqual(left, left)
        
        var right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 0, countOfAlternatives: 0, name: nil, matchingIndex: 0, waypointIndex: 0)
        XCTAssertEqual(left, right)
        
        right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1), correction: 0, countOfAlternatives: 0, name: nil, matchingIndex: 0, waypointIndex: 0)
        XCTAssertNotEqual(left, right)

        right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 1, countOfAlternatives: 0, name: nil, matchingIndex: 0, waypointIndex: 0)
        XCTAssertNotEqual(left, right)

        right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 0, countOfAlternatives: 1, name: nil, matchingIndex: 0, waypointIndex: 0)
        XCTAssertNotEqual(left, right)
        
        right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 0, countOfAlternatives: 9, name: "", matchingIndex: 0, waypointIndex: 0)
        XCTAssertNotEqual(left, right)
        
        right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 0, countOfAlternatives: 0, name: nil, matchingIndex: 1, waypointIndex: 0)
        XCTAssertNotEqual(left, right)
        
        right = Match.Tracepoint(coordinate: CLLocationCoordinate2D(), correction: 0, countOfAlternatives: 0, name: nil, matchingIndex: 0, waypointIndex: 1)
        XCTAssertNotEqual(left, right)
    }
    
    func testAccuracies() {
        let from = RouteOptions.Waypoint(location: CLLocation(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                                              altitude: -1,
                                                              horizontalAccuracy: -1,
                                                              verticalAccuracy: -1,
                                                              timestamp: Date()))
        let to = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        let options = RouteOptions(waypoints: [from, to])
        XCTAssertNil(options.bearings)
        XCTAssertNil(options.radiuses)
        
        options.waypoints[0].heading = 90
        options.waypoints[0].headingAccuracy = 45
        XCTAssertEqual(options.bearings, "90.0,45.0;")
        
        options.waypoints[0].coordinateAccuracy = 5
        XCTAssertEqual(options.radiuses, "5.0;unlimited")
    }
}
