import XCTest
#if !os(Linux)
import OHHTTPStubs
#if SWIFT_PACKAGE
import OHHTTPStubsSwift
#endif
@testable import MapboxDirections

class RoutableMatchTest: XCTestCase {
    override func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }
    
    func testRoutableMatch() {
        let expectation = self.expectation(description: "calculating directions should return results")
        let locations = [CLLocationCoordinate2D(latitude: 32.712041, longitude: -117.172836),
                         CLLocationCoordinate2D(latitude: 32.712256, longitude: -117.17291),
                         CLLocationCoordinate2D(latitude: 32.712444, longitude: -117.17292),
                         CLLocationCoordinate2D(latitude: 32.71257, longitude: -117.172922),
                         CLLocationCoordinate2D(latitude: 32.7126, longitude: -117.172985),
                         CLLocationCoordinate2D(latitude: 32.712597, longitude: -117.173143),
                         CLLocationCoordinate2D(latitude: 32.712546, longitude: -117.173345)]
        
        stub(condition: isHost("api.mapbox.com")
            && isMethodGET()
            && pathStartsWith("/matching/v5/mapbox/driving")) { _ in
                let path = Bundle.module.path(forResource: "match-polyline6", ofType: "json")
                return HTTPStubsResponse(fileAtPath: path!, statusCode: 200, headers: ["Content-Type": "application/json"])
        }
        
        var routeResponse: RouteResponse!
        
        let matchOptions = MatchOptions(coordinates: locations)
        matchOptions.shapeFormat = .polyline6
        matchOptions.includesSteps = true
        matchOptions.routeShapeResolution = .full
        for waypoint in matchOptions.waypoints[1..<(locations.count - 1)] {
            waypoint.separatesLegs = false
        }
        
        let task = Directions(credentials: BogusCredentials).calculateRoutes(matching: matchOptions) { (session, result) in
            
            switch (result) {
            case let .failure(error):
                XCTFail("Error: \(error)")
            case let .success(response):
                routeResponse = response
                expectation.fulfill()
            }
                        
        }
        XCTAssertNotNil(task)
        
        waitForExpectations(timeout: 200000) { (error) in
            XCTAssertNil(error, "Error: \(error!)")
            XCTAssertEqual(task.state, .completed)
        }
        
        let route = routeResponse.routes!.first!
        XCTAssertNotNil(route)
        XCTAssertNotNil(route.shape)
        XCTAssertEqual(route.shape!.coordinates.count, 19)
        
        let waypoints = routeResponse.waypoints!
        XCTAssertNotNil(waypoints)
        XCTAssertEqual(waypoints.first!.name, "North Harbor Drive")
        XCTAssertEqual(waypoints.last!.name, "West G Street")
        XCTAssertNotNil(waypoints.last!.coordinate)
        
        // confirming actual decoded values is important because the Directions API
        // uses an atypical precision level for polyline encoding
        XCTAssertEqual(round(route.shape!.coordinates.first!.latitude), 33)
        XCTAssertEqual(round(route.shape!.coordinates.first!.longitude), -117)
        XCTAssertEqual(route.legs.count, 6)
        
        let leg = route.legs.first!
        XCTAssertEqual(leg.name, "North Harbor Drive")
        XCTAssertEqual(leg.steps.count, 2)
        
        let firstStep = leg.steps.first
        XCTAssertNotNil(firstStep)
        let firstStepIntersections = firstStep?.intersections
        XCTAssertNotNil(firstStepIntersections)
        let firstIntersection = firstStepIntersections?.first
        XCTAssertNotNil(firstIntersection)
        
        let step = leg.steps[0]
        XCTAssertEqual(round(step.distance), 25)
        XCTAssertEqual(round(step.expectedTravelTime), 3)
        XCTAssertEqual(step.instructions, "Head north on North Harbor Drive")
        
        XCTAssertEqual(step.maneuverType, .depart)
        XCTAssertEqual(step.maneuverDirection, .none)
        XCTAssertEqual(step.initialHeading, 0)
        XCTAssertEqual(step.finalHeading, 340)
        
        XCTAssertNotNil(step.shape)
        XCTAssertEqual(step.shape!.coordinates.count, 5)
        let coordinate = step.shape!.coordinates.first!
        XCTAssertEqual(round(coordinate.latitude), 33)
        XCTAssertEqual(round(coordinate.longitude), -117)
    }
}
#endif
