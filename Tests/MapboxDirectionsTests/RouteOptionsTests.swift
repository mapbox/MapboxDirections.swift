import XCTest
import CoreLocation
@testable import MapboxDirections

class RouteOptionsTests: XCTestCase {
    func testCoding() {
        let options = testRouteOptions
        
        let encoded: Data = try! JSONEncoder().encode(options)
        let optionsString: String = String(data: encoded, encoding: .utf8)!
        
        let unarchivedOptions: RouteOptions = try! JSONDecoder().decode(RouteOptions.self, from: optionsString.data(using: .utf8)!)
        
        XCTAssertNotNil(unarchivedOptions)
        
        let coordinates = testCoordinates
        let unarchivedWaypoints = unarchivedOptions.waypoints
        XCTAssertEqual(unarchivedWaypoints.count, coordinates.count)
        XCTAssertEqual(unarchivedWaypoints[0].coordinate.latitude, coordinates[0].latitude)
        XCTAssertEqual(unarchivedWaypoints[0].coordinate.longitude, coordinates[0].longitude)
        XCTAssertEqual(unarchivedWaypoints[1].coordinate.latitude, coordinates[1].latitude)
        XCTAssertEqual(unarchivedWaypoints[1].coordinate.longitude, coordinates[1].longitude)
        XCTAssertEqual(unarchivedWaypoints[2].coordinate.latitude, coordinates[2].latitude)
        XCTAssertEqual(unarchivedWaypoints[2].coordinate.longitude, coordinates[2].longitude)
        
        XCTAssertEqual(unarchivedOptions.profileIdentifier, options.profileIdentifier)
        XCTAssertEqual(unarchivedOptions.locale, options.locale)
        XCTAssertEqual(unarchivedOptions.includesSpokenInstructions, options.includesSpokenInstructions)
        XCTAssertEqual(unarchivedOptions.distanceMeasurementSystem, options.distanceMeasurementSystem)
        XCTAssertEqual(unarchivedOptions.includesVisualInstructions, options.includesVisualInstructions)
        XCTAssertEqual(unarchivedOptions.roadClassesToAvoid, options.roadClassesToAvoid)
    }
    
    // MARK: API name-handling tests
    
    private static var testWaypoints: [RouteOptions.Waypoint] {
        return [
            RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 39.27664, longitude:-84.41139)),
            RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 39.27277, longitude:-84.41226)),
        ]
    }
    
    private func response(for fixtureName: String, waypoints: [RouteOptions.Waypoint] = testWaypoints) -> (waypoints: [Route.Waypoint], route: Route)? {
        let testBundle = Bundle(for: type(of: self))
        guard let fixtureURL = testBundle.url(forResource:fixtureName, withExtension:"json") else {
            XCTFail()
            return nil
        }
        guard let fixtureData = try? Data(contentsOf: fixtureURL, options:.mappedIfSafe) else {
            XCTFail()
            return nil
        }
    
        let subject = RouteOptions(waypoints: waypoints)
        let decoder = JSONDecoder()
        decoder.userInfo[.options] = subject
        decoder.userInfo[.credentials] = DirectionsCredentials(accessToken: "foo", host: URL(string: "https://test.website")!)
        var response: RouteResponse?
        XCTAssertNoThrow(response = try decoder.decode(RouteResponse.self, from: fixtureData))
        XCTAssertNotNil(response)
        
        if let response = response {
            XCTAssertNotNil(response.waypoints)
            XCTAssertNotNil(response.routes)
        }
        guard let waypoints = response?.waypoints, let route = response?.routes?.first else {
            return nil
        }
        return (waypoints: waypoints, route: route)
    }
    
    func testResponseWithoutDestinationName() {
        // https://api.mapbox.com/directions/v5/mapbox/driving/-84.411389,39.27665;-84.412115,39.272675.json?overview=false&steps=false&access_token=pk.feedcafedeadbeef
        let response = self.response(for: "noDestinationName")!
        XCTAssertNil(response.route.legs.last?.destination?.name, "Empty-string waypoint name in API responds should be represented as nil.")
    }
    
    func testResponseWithDestinationName() {
        // https://api.mapbox.com/directions/v5/mapbox/driving/-84.411389,39.27665;-84.41195,39.27260.json?overview=false&steps=false&access_token=pk.feedcafedeadbeef
        let response = self.response(for: "apiDestinationName")!
        XCTAssertEqual(response.route.legs.last?.destination?.name, "Reading Road", "Waypoint name in fixture response not parsed correctly.")
    }
    
    func testResponseWithManuallySetDestinationName() {
        var manuallySet = RouteOptionsTests.testWaypoints
        manuallySet[manuallySet.endIndex.advanced(by: -1)].name = "manuallyset"
        
        let response = self.response(for: "apiDestinationName", waypoints: manuallySet)!
        XCTAssertEqual(response.route.legs.last?.destination?.name, "manuallyset", "Waypoint with manually set name should override any computed name.")
    }
    
    func testApproachesURLQueryParams() {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        var wp1 = RouteOptions.Waypoint(coordinate: coordinate, coordinateAccuracy: 0)
        wp1.allowsArrivingOnOppositeSide = false
        let waypoints = [
            RouteOptions.Waypoint(coordinate: coordinate, coordinateAccuracy: 0),
            wp1,
            RouteOptions.Waypoint(coordinate: coordinate, coordinateAccuracy: 0)
        ]
        
        let routeOptions = RouteOptions(waypoints: waypoints)
        routeOptions.includesSteps = true
        let urlQueryItems = routeOptions.urlQueryItems
        let approaches = urlQueryItems.filter { $0.name == "approaches" }.first!
        XCTAssertEqual(approaches.value!, "unrestricted;curb;unrestricted", "waypoints[1] should be restricted to curb")
    }
    
    func testMissingApproaches() {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let waypoints = [
            RouteOptions.Waypoint(coordinate: coordinate, coordinateAccuracy: 0),
            RouteOptions.Waypoint(coordinate: coordinate, coordinateAccuracy: 0),
            RouteOptions.Waypoint(coordinate: coordinate, coordinateAccuracy: 0)
        ]
        
        let routeOptions = RouteOptions(waypoints: waypoints)
        routeOptions.includesSteps = true
        let urlQueryItems = routeOptions.urlQueryItems
        let hasApproaches = !urlQueryItems.filter { $0.name == "approaches" }.isEmpty
        XCTAssertFalse(hasApproaches, "approaches query param should be omitted unless any waypoint is restricted to curb")
    }
    
    func testDecimalPrecision() {
        let start = CLLocationCoordinate2D(latitude: 9.945497000000003, longitude: 53.03218800000006)
        let end = CLLocationCoordinate2D(latitude: 10.945497000000003, longitude: 54.03218800000006)
        
        let answer = [start.requestDescription, end.requestDescription]
        let correct = ["53.032188,9.945497", "54.032188,10.945497"]
        XCTAssert(answer == correct, "Coordinates should be truncated.")
    }
    
    func testWaypointSerialization() {
        let origin = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 39.15031, longitude: -84.47182), name: "XU")
        var destination = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 39.12971, longitude: -84.51638), name: "UC")
        destination.targetCoordinate = CLLocationCoordinate2D(latitude: 39.13115, longitude: -84.51619)
        let options = RouteOptions(waypoints: [origin, destination])
        XCTAssertEqual(options.coordinates, "-84.47182,39.15031;-84.51638,39.12971")
        XCTAssertTrue(options.urlQueryItems.contains(URLQueryItem(name: "waypoint_names", value: "XU;UC")))
        XCTAssertTrue(options.urlQueryItems.contains(URLQueryItem(name: "waypoint_targets", value: ";-84.51619,39.13115")))
    }
}

fileprivate let testCoordinates = [
    CLLocationCoordinate2D(latitude: 52.5109, longitude: 13.4301),
    CLLocationCoordinate2D(latitude: 52.5080, longitude: 13.4265),
    CLLocationCoordinate2D(latitude: 52.5021, longitude: 13.4316),
]

var testRouteOptions: RouteOptions {
    let opts = RouteOptions(coordinates: testCoordinates, profileIdentifier: .automobileAvoidingTraffic)
    opts.locale = Locale(identifier: "en_US")
    opts.allowsUTurnAtWaypoint = true
    opts.shapeFormat = .polyline
    opts.routeShapeResolution = .full
    opts.attributeOptions = [.congestionLevel]
    opts.includesExitRoundaboutManeuver = true
    opts.includesSpokenInstructions = true
    opts.distanceMeasurementSystem = .metric
    opts.includesVisualInstructions = true
    opts.roadClassesToAvoid = .toll

    return opts
}
