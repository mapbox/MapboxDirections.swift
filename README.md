# Mapbox Directions for Swift

[![CircleCI](https://circleci.com/gh/mapbox/mapbox-directions-swift.svg?style=svg)](https://circleci.com/gh/mapbox/mapbox-directions-swift)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods](https://img.shields.io/cocoapods/v/MapboxDirections.svg)](https://cocoapods.org/pods/MapboxDirections/)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![codecov](https://codecov.io/gh/mapbox/mapbox-directions-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/mapbox/mapbox-directions-swift)

Mapbox Directions for Swift (formerly MapboxDirections.swift) makes it easy to connect your iOS, macOS, tvOS, or watchOS application to the [Mapbox Directions](https://docs.mapbox.com/api/navigation/) and [Map Matching](https://docs.mapbox.com/api/navigation/#map-matching) APIs. Quickly get driving, cycling, or walking directions, whether the trip is nonstop or it has multiple stopping points, all using a simple interface reminiscent of MapKit’s `MKDirections` API. Fit a GPX trace to the [OpenStreetMap](https://www.openstreetmap.org/) road network. The Mapbox Directions and Map Matching APIs are powered by the [OSRM](http://project-osrm.org/) and [Valhalla](https://github.com/valhalla/valhalla/) routing engines. For more information, see the [Mapbox Navigation](https://www.mapbox.com/navigation/) homepage.

Mapbox Directions pairs well with [MapboxGeocoder.swift](https://github.com/mapbox/MapboxGeocoder.swift), [MapboxStatic.swift](https://github.com/mapbox/MapboxStatic.swift), the [Mapbox Navigation SDK for iOS](https://github.com/mapbox/mapbox-navigation-ios/), and the [Mapbox Maps SDK for iOS](https://docs.mapbox.com/ios/maps/) or [macOS SDK](https://mapbox.github.io/mapbox-gl-native/macos/).

## Getting started

Specify the following dependency in your [Carthage](https://github.com/Carthage/Carthage) Cartfile:

```cartfile
github "mapbox/mapbox-directions-swift" ~> 0.31
```

Or in your [CocoaPods](http://cocoapods.org/) Podfile:

```podspec
pod 'MapboxDirections', '~> 0.31'
```

Or in your [Swift Package Manager](https://swift.org/package-manager/) Package.swift:

```swift
.package(url: "https://github.com/mapbox/mapbox-directions-swift.git", from: "0.31.0")
```

Then `import MapboxDirections`.

This library supports a minimum deployment target of iOS 10.0 or above, macOS 10.12.0 or above, tvOS 10.0 or above, or watchOS 2.0 or above. v0.30.0 is the last release of MapboxDirections.swift that supports a minimum deployment target of iOS 9._x_, macOS 10.11._x_, tvOS 9._x_, or watchOS 2._x_. v0.30.0 is also the last release that is compatible with Objective-C or AppleScript code.

This repository contains an example application that demonstrates how to use the framework. To run it, you need to use [Carthage](https://github.com/Carthage/Carthage) 0.19 or above to install the dependencies. Detailed documentation is available in the [Mapbox API Documentation](https://docs.mapbox.com/api/navigation/#directions).

## Usage

**[API reference](https://docs.mapbox.com/ios/api/directions/)**

You’ll need a [Mapbox access token](https://docs.mapbox.com/api/#access-tokens-and-token-scopes) in order to use the API. If you’re already using the [Mapbox Maps SDK for iOS](https://docs.mapbox.com/ios/maps/) or [macOS SDK](https://mapbox.github.io/mapbox-gl-native/macos/), Mapbox Directions automatically recognizes your access token, as long as you’ve placed it in the `MGLMapboxAccessToken` key of your application’s Info.plist file.

The examples below are each provided in Swift (denoted with `main.swift`), For further details, see the [Mapbox Directions for Swift API reference](https://docs.mapbox.com/ios/api/directions/).

### Calculating directions between locations

The main directions class is `Directions`. Create a directions object using your access token:

```swift
// main.swift
import MapboxDirections

let directions = Directions(accessToken: "<#your access token#>")
```

Alternatively, you can place your access token in the `MGLMapboxAccessToken` key of your application’s Info.plist file, then use the shared directions object:

```swift
// main.swift
let directions = Directions.shared
```

With the directions object in hand, construct a RouteOptions object and pass it into the `Directions.calculate(_:completionHandler:)` method.

```swift
// main.swift

let waypoints = [
    RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.9131752, longitude: -77.0324047), name: "Mapbox"),
    RouteOptions.Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), name: "White House"),
]
let options = RouteOptions(waypoints: waypoints, profileIdentifier: .automobileAvoidingTraffic)
options.includesSteps = true

let task = directions.calculate(options) { (waypoints, routes, error) in
    guard error == nil else {
        print("Error calculating directions: \(error!)")
        return
    }

    if let route = routes?.first, let leg = route.legs.first {
        print("Route via \(leg):")

        let distanceFormatter = LengthFormatter()
        let formattedDistance = distanceFormatter.string(fromMeters: route.distance)

        let travelTimeFormatter = DateComponentsFormatter()
        travelTimeFormatter.unitsStyle = .short
        let formattedTravelTime = travelTimeFormatter.string(from: route.expectedTravelTime)

        print("Distance: \(formattedDistance); ETA: \(formattedTravelTime!)")

        for step in leg.steps {
            print("\(step.instructions)")
            let formattedDistance = distanceFormatter.string(fromMeters: step.distance)
            print("— \(formattedDistance) —")
        }
    }
}
```

This library uses version 5 of the Mapbox Directions API by default. To use version 4 instead, replace RouteOptions with RouteOptionsV4.

### Matching a trace to the road network

If you have a GPX trace or other GPS-derived location data, you can clean up the data and fit it to the road network using the Map Matching API:

```swift
// main.swift

let coordinates = [
    CLLocationCoordinate2D(latitude: 32.712041, longitude: -117.172836),
    CLLocationCoordinate2D(latitude: 32.712256, longitude: -117.17291),
    CLLocationCoordinate2D(latitude: 32.712444, longitude: -117.17292),
    CLLocationCoordinate2D(latitude: 32.71257,  longitude: -117.172922),
    CLLocationCoordinate2D(latitude: 32.7126,   longitude: -117.172985),
    CLLocationCoordinate2D(latitude: 32.712597, longitude: -117.173143),
    CLLocationCoordinate2D(latitude: 32.712546, longitude: -117.173345)
]

let options = MatchOptions(coordinates: coordinates)
options.includesSteps = true

let task = directions.calculate(options) { (matches, error) in
    guard error == nil else {
        print("Error matching coordinates: \(error!)")
        return
    }

    if let match = matches?.first, let leg = match.legs.first {
        print("Match via \(leg):")

        let distanceFormatter = LengthFormatter()
        let formattedDistance = distanceFormatter.string(fromMeters: match.distance)

        let travelTimeFormatter = DateComponentsFormatter()
        travelTimeFormatter.unitsStyle = .short
        let formattedTravelTime = travelTimeFormatter.string(from: match.expectedTravelTime)

        print("Distance: \(formattedDistance); ETA: \(formattedTravelTime!)")

        for step in leg.steps {
            print("\(step.instructions)")
            let formattedDistance = distanceFormatter.string(fromMeters: step.distance)
            print("— \(formattedDistance) —")
        }
    }
}
```

You can also use the `Directions.calculateRoutes(matching:completionHandler:)` method to get Route objects suitable for use anywhere a standard Directions API response would be used.

## Usage with other Mapbox libraries

### Drawing the route on a map

With the [Mapbox Maps SDK for iOS](https://docs.mapbox.com/ios/maps/) or [macOS SDK](https://mapbox.github.io/mapbox-gl-native/macos/), you can easily draw the route on a map:

```swift
// main.swift

if var routeCoordinates = route.shape?.coordinates, routeCoordinates.count > 0 {
    // Convert the route’s coordinates into a polyline.
    let routeLine = MGLPolyline(coordinates: &routeCoordinates, count: UInt(routeCoordinates.count))

    // Add the polyline to the map.
    mapView.addAnnotation(routeLine)
    
    // Fit the viewport to the polyline.
    let camera = mapView.cameraThatFitsShape(routeLine, direction: 0, edgePadding: .zero)
    mapView.setCamera(camera, animated: true)
}
```

### Displaying a turn-by-turn navigation interface

See the [Mapbox Navigation SDK for iOS](https://github.com/mapbox/mapbox-navigation-ios/#usage) documentation for usage examples.

## Tests

To run the included unit tests, you need to use [Carthage](https://github.com/Carthage/Carthage) 0.19 or above to install the dependencies.

1. `carthage build --platform iOS`
1. `open MapboxDirections.xcodeproj`
1. Go to Product ‣ Test.
