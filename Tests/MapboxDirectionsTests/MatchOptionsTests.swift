import XCTest
import CoreLocation
@testable import MapboxDirections

class MatchOptionsTests: XCTestCase {
    func testCoding() {
        let options = testMatchOptions
        
        let encoded: Data = try! JSONEncoder().encode(options)
        let optionsString: String = String(data: encoded, encoding: .utf8)!
        
        let unarchivedOptions: MatchOptions = try! JSONDecoder().decode(MatchOptions.self, from: optionsString.data(using: .utf8)!)
        
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
        
        XCTAssertEqual(unarchivedOptions.resamplesTraces, options.resamplesTraces)
    }
    
    // MARK: API name-handling tests
    
    private static var testTracepoints: [Match.Tracepoint] {
        let one = CLLocationCoordinate2D(latitude: 39.27664, longitude:-84.41139)
        let two = CLLocationCoordinate2D(latitude: 39.27277, longitude:-84.41226)
        return [one, two].map {
            Match.Tracepoint(coordinate: $0, correction: 0, countOfAlternatives: 0, name: nil, matchingIndex: 0, waypointIndex: 0)
        }
    }

    
    func testWaypointSerialization() {
        let origin = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 39.15031, longitude: -84.47182), name: "XU")
        let destination = RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 39.12971, longitude: -84.51638), name: "UC")
        let options = MatchOptions(waypoints: [origin, destination])
        XCTAssertEqual(options.coordinates, "-84.47182,39.15031;-84.51638,39.12971")
        XCTAssertTrue(options.urlQueryItems.contains(URLQueryItem(name: "waypoint_names", value: "XU;UC")))
    }
    
    func testRouteOptionsConvertedFromMatchOptions() {
        let matchOpts = testMatchOptions
        let subject = RouteOptions(matchOptions: matchOpts)
        
        XCTAssertEqual(subject.includesSteps, matchOpts.includesSteps)
        XCTAssertEqual(subject.shapeFormat, matchOpts.shapeFormat)
        XCTAssertEqual(subject.attributeOptions, matchOpts.attributeOptions)
        XCTAssertEqual(subject.routeShapeResolution, matchOpts.routeShapeResolution)
        XCTAssertEqual(subject.locale, matchOpts.locale)
        XCTAssertEqual(subject.includesSpokenInstructions, matchOpts.includesSpokenInstructions)
        XCTAssertEqual(subject.includesVisualInstructions, matchOpts.includesVisualInstructions)
    }
}

fileprivate let testCoordinates = [
    CLLocationCoordinate2D(latitude: 52.5109, longitude: 13.4301),
    CLLocationCoordinate2D(latitude: 52.5080, longitude: 13.4265),
    CLLocationCoordinate2D(latitude: 52.5021, longitude: 13.4316),
]


var testMatchOptions: MatchOptions {
    let opts = MatchOptions(coordinates: testCoordinates, profileIdentifier: .automobileAvoidingTraffic)
    opts.resamplesTraces = true
    return opts
}
