import XCTest
#if !os(Linux)
#if SWIFT_PACKAGE
import OHHTTPStubsSwift
#endif
import OHHTTPStubs
@testable import MapboxDirections

class AnnotationTests: XCTestCase {
    override func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }
    
    func testAnnotation() {
        let expectation = self.expectation(description: "calculating directions should return results")
        
        let queryParams: [String: String?] = [
            "alternatives": "false",
            "geometries": "polyline",
            "overview": "full",
            "steps": "false",
            "continue_straight": "true",
            "access_token": BogusToken,
            "annotations": "distance,duration,speed,congestion,maxspeed"
        ]
        
        stub(condition: isHost("api.mapbox.com")
                && containsQueryParams(queryParams)) { _ in
            let path = Bundle.module.path(forResource: "annotation", ofType: "json")
            return HTTPStubsResponse(fileAtPath: path!, statusCode: 200, headers: ["Content-Type": "application/json"])
        }
        
        let options = RouteOptions(coordinates: [
            CLLocationCoordinate2D(latitude: 37.780602, longitude: -122.431373),
            CLLocationCoordinate2D(latitude: 37.758859, longitude: -122.404058),
        ], profileIdentifier: .automobileAvoidingTraffic)
        options.shapeFormat = .polyline
        options.includesSteps = false
        options.includesAlternativeRoutes = false
        options.routeShapeResolution = .full
        options.attributeOptions = [.distance, .expectedTravelTime, .speed, .congestionLevel, .maximumSpeedLimit]
        var route: Route?
        let task = Directions(credentials: BogusCredentials).calculate(options) { (session, disposition) in
            
            switch disposition {
            case let .failure(error):
                XCTFail("Error! \(error)")
            case let .success(response):
                XCTAssertNotNil(response.routes)
                XCTAssertEqual(response.routes!.count, 1)
                route = response.routes!.first!
                
                expectation.fulfill()
            }

        }
        XCTAssertNotNil(task)
        
        waitForExpectations(timeout: 2) { (error) in
            XCTAssertNil(error, "Error: \(error!.localizedDescription)")
            XCTAssertEqual(task.state, .completed)
        }
        
        XCTAssertNotNil(route)
        if let route = route {
            XCTAssertNotNil(route.shape)
            XCTAssertEqual(route.shape?.coordinates.count, 154)
            XCTAssertEqual(route.legs.count, 1)
        }
        
        if let leg = route?.legs.first {
            XCTAssertEqual(leg.segmentDistances?.count, 153)
            XCTAssertEqual(leg.segmentSpeeds?.count, 153)
            XCTAssertEqual(leg.expectedSegmentTravelTimes?.count, 153)
            
            XCTAssertEqual(leg.segmentCongestionLevels?.count, 153)
            XCTAssertFalse(leg.segmentCongestionLevels?.contains(.unknown) ?? true)
            XCTAssertEqual(leg.segmentCongestionLevels?.firstIndex(of: .low), 0)
            XCTAssertEqual(leg.segmentCongestionLevels?.firstIndex(of: .moderate), 21)
            XCTAssertEqual(leg.segmentCongestionLevels?.firstIndex(of: .heavy), 2)
            XCTAssertFalse(leg.segmentCongestionLevels?.contains(.severe) ?? true)
            
            XCTAssertEqual(leg.segmentMaximumSpeedLimits?.count, 153)
            XCTAssertEqual(leg.segmentMaximumSpeedLimits?.first, Measurement(value: 48, unit: .kilometersPerHour))
            XCTAssertEqual(leg.segmentMaximumSpeedLimits?.firstIndex(of: nil), 2)
            XCTAssertFalse(leg.segmentMaximumSpeedLimits?.contains(Measurement(value: .infinity, unit: .kilometersPerHour)) ?? true)
        }
    }
    
    func testSpeedLimits() {
        func assert(_ speedLimitDescriptorJSON: [String: Any], roundTripsWith expectedSpeedLimitDescriptor: SpeedLimitDescriptor) {
            let speedLimitDescriptorData = try! JSONSerialization.data(withJSONObject: speedLimitDescriptorJSON, options: [])
            var speedLimitDescriptor: SpeedLimitDescriptor?
            XCTAssertNoThrow(speedLimitDescriptor = try JSONDecoder().decode(SpeedLimitDescriptor.self, from: speedLimitDescriptorData))
            XCTAssertEqual(speedLimitDescriptor, expectedSpeedLimitDescriptor)
            
            speedLimitDescriptor = expectedSpeedLimitDescriptor
            
            let encoder = JSONEncoder()
            var encodedData: Data?
            XCTAssertNoThrow(encodedData = try encoder.encode(speedLimitDescriptor))
            XCTAssertNotNil(encodedData)
            if let encodedData = encodedData {
                var encodedSpeedLimitDescriptorJSON: [String: Any?]?
                XCTAssertNoThrow(encodedSpeedLimitDescriptorJSON = try JSONSerialization.jsonObject(with: encodedData, options: []) as? [String: Any?])
                XCTAssertNotNil(encodedSpeedLimitDescriptorJSON)
                
                XCTAssert(JSONSerialization.objectsAreEqual(speedLimitDescriptorJSON, encodedSpeedLimitDescriptorJSON, approximate: true))
            }
        }
        
        XCTAssertEqual(SpeedLimitDescriptor(speed: Measurement(value: 55, unit: .milesPerHour)),
                       .some(speed: Measurement(value: 55, unit: .milesPerHour)))
        XCTAssertEqual(Measurement<UnitSpeed>(speedLimitDescriptor: .some(speed: Measurement(value: 55, unit: .milesPerHour))),
                       Measurement(value: 55, unit: .milesPerHour))
        assert(["speed": 55.0, "unit": "mph"], roundTripsWith: .some(speed: Measurement(value: 55, unit: .milesPerHour)))
        
        XCTAssertEqual(SpeedLimitDescriptor(speed: Measurement(value: 80, unit: .kilometersPerHour)),
                       .some(speed: Measurement(value: 80, unit: .kilometersPerHour)))
        XCTAssertEqual(Measurement<UnitSpeed>(speedLimitDescriptor: .some(speed: Measurement(value: 80, unit: .kilometersPerHour))),
                       Measurement(value: 80, unit: .kilometersPerHour))
        assert(["speed": 80.0, "unit": "km/h"], roundTripsWith: .some(speed: Measurement(value: 80, unit: .kilometersPerHour)))
        
        XCTAssertEqual(SpeedLimitDescriptor(speed: nil), .unknown)
        XCTAssertNil(Measurement<UnitSpeed>(speedLimitDescriptor: .unknown))
        assert(["unknown": true], roundTripsWith: .unknown)
        
        XCTAssertEqual(SpeedLimitDescriptor(speed: Measurement(value: .infinity, unit: .kilometersPerHour)), .none)
        XCTAssertEqual(Measurement<UnitSpeed>(speedLimitDescriptor: .none),
                       Measurement(value: .infinity, unit: .kilometersPerHour))
        assert(["none": true], roundTripsWith: .none)
    }
}
#endif
