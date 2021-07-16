import Foundation
import SwiftUI
import Combine
import MapboxDirections

final class DirectionsViewModel: ObservableObject {
    private let distanceFormatter: LengthFormatter = .init()
    private let travelTimeFormatter: DateComponentsFormatter = .init()

    @Published
    var routes: [Route] = []

    init() {
        travelTimeFormatter.unitsStyle = .short
    }

    func loadRoutes() {
        let startPoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.9131752, longitude: -77.0324047),
                                  name: "Mapbox")
        let stopPoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.89065720, longitude: -77.0090701),
                            name: "Capitol")
        let endPoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                                name: "White House")
        let options = RouteOptions(waypoints: [startPoint, stopPoint, endPoint])
        options.includesSteps = true
        options.routeShapeResolution = .full
        options.attributeOptions = [.congestionLevel, .maximumSpeedLimit]

        Directions.shared.calculate(options) { (session, result) in
            switch result {
            case let .failure(error):
                print("Error calculating directions: \(error)")
            case let .success(response):
                self.routes = response.routes ?? []
            }
        }
    }

    func formattedDistance(for route: Route) -> String {
        return distanceFormatter.string(fromMeters: route.distance)
    }

    func formattedTravelTime(for route: Route) -> String {
        return travelTimeFormatter.string(from: route.expectedTravelTime)!
    }

    func formattedTypicalTravelTime(for route: Route) -> String {
        if let typicalTravelTime = route.typicalTravelTime,
           let formattedTypicalTravelTime = travelTimeFormatter.string(from: typicalTravelTime) {
            return formattedTypicalTravelTime
        }
        else {
            return "Not available"
        }
    }

    func stepDescriptions(for step: RouteStep) -> String {
        var description: String = ""
        let direction = step.maneuverDirection?.rawValue ?? "none"
        description.append("\(step.instructions) [\(step.maneuverType) \(direction)]")
        if step.distance > 0 {
            let formattedDistance = distanceFormatter.string(fromMeters: step.distance)
            description.append(" (\(step.transportType) for \(formattedDistance))")
        }
        return description
    }
}

struct ContentView: View {
    @ObservedObject
    var vm: DirectionsViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10, content: {
                ForEach(vm.routes, id: \.distance) { route in
                    VStack(alignment: .leading, spacing: 3) {
                        headerView(for: route)
                        ForEach(0..<route.legs.count, id: \.self) { legIdx in
                            if let source = route.legs[legIdx].source?.name,
                               let destination = route.legs[legIdx].destination?.name {
                                Text("From '\(source)' to '\(destination)'").font(.title2)
                            }
                            else {
                                Text("Steps:").font(.title2)
                            }
                            stepsView(for: route.legs[legIdx])
                        }
                    }
                }
            })
        }
        .padding(5)
        .onAppear { vm.loadRoutes() }
    }

    @ViewBuilder
    private func headerView(for route: Route) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Route: ").fontWeight(.bold)
                Text(route.description)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text("Distance: ").fontWeight(.bold)
                Text(vm.formattedDistance(for:route))
            }
            HStack {
                Text("ETA: ").fontWeight(.bold)
                Text(vm.formattedTravelTime(for: route))
            }
            HStack {
                Text("Typical travel time: ").fontWeight(.bold)
                Text(vm.formattedTypicalTravelTime(for: route))
            }
            Divider()
        }
    }

    @ViewBuilder
    private func stepsView(for leg: RouteLeg) -> some View {
        LazyVStack(alignment: .leading, spacing: 5, content: {
            ForEach(0..<leg.steps.count, id: \.self) { stepIdx in
                HStack {
                    Text("\(stepIdx + 1). ").fontWeight(.bold)
                    Text(vm.stepDescriptions(for: leg.steps[stepIdx]))
                }
                .padding([.top, .bottom], 3)

                Divider()
            }
        })
    }
}
