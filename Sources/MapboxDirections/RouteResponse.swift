import Foundation

public enum ResponseOptions {
    case route(RouteOptions)
    case match(MatchOptions)
}

public struct RouteResponse {
    public let httpResponse: HTTPURLResponse?
    
    public let identifier: String?
    public var routes: [Route]?    
    public let waypoints: [Route.Waypoint]?
    
    public let options: ResponseOptions
    public let credentials: DirectionsCredentials
    
    /**
     The time when this `RouteResponse` object was created, which is immediately upon recieving the raw URL response.
     
     If you manually start fetching a task returned by `Directions.url(forCalculating:)`, this property is set to `nil`; use the `URLSessionTaskTransactionMetrics.responseEndDate` property instead. This property may also be set to `nil` if you create this result from a JSON object or encoded object.
     
     This property does not persist after encoding and decoding.
     */
    public var created: Date = Date()
}

extension RouteResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "uuid"
        case routes
        case waypoints
    }
    
    public init(httpResponse: HTTPURLResponse?, identifier: String? = nil, routes: [Route]? = nil, waypoints: [Route.Waypoint]? = nil, options: ResponseOptions, credentials: DirectionsCredentials) {
        self.httpResponse = httpResponse
        self.identifier = identifier
        self.routes = routes
        self.waypoints = waypoints
        self.options = options
        self.credentials = credentials
    }
    
    public init(matching response: MapMatchingResponse, options: MatchOptions, credentials: DirectionsCredentials) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        
        decoder.userInfo[.options] = options
        decoder.userInfo[.credentials] = credentials
        
        var routes: [Route]?
        
        if let matches = response.matches {
            let matchesData = try encoder.encode(matches)
            routes = try decoder.decode([Route].self, from: matchesData)
        }
        
        var waypoints: [Route.Waypoint]?
        
        if let tracepoints = response.tracepoints {
            let filtered = tracepoints.compactMap { $0 }
            let tracepointsData = try encoder.encode(filtered)
            waypoints = try decoder.decode([Route.Waypoint].self, from: tracepointsData)
        }
    
        self.init(httpResponse: response.httpResponse, identifier: nil, routes: routes, waypoints: waypoints, options: .match(options), credentials: credentials)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.httpResponse = decoder.userInfo[.httpResponse] as? HTTPURLResponse
        
        guard let credentials = decoder.userInfo[.credentials] as? DirectionsCredentials else {
            throw DirectionsCodingError.missingCredentials
        }
        
        self.credentials = credentials
        
        if let options = decoder.userInfo[.options] as? RouteOptions {
            self.options = .route(options)
        } else if let options = decoder.userInfo[.options] as? MatchOptions {
            self.options = .match(options)
        } else {
            throw DirectionsCodingError.missingOptions
        }
        
        self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        
        // Decode waypoints from the response and update their names according to the waypoints from DirectionsOptions.waypoints.
        let decodedWaypoints = try container.decodeIfPresent([Route.Waypoint?].self, forKey: .waypoints)?.compactMap{ $0 }
        var optionsWaypoints: [Route.Waypoint] = []
        
        switch options {
        case let .match(options: matchOpts):
            optionsWaypoints = matchOpts.waypoints.map {
                Route.Waypoint(coordinate: $0.coordinate,
                               correction: 0,
                               name: $0.name)
            }
        case let .route(options: routeOpts):
            optionsWaypoints = routeOpts.waypoints.map {
                Route.Waypoint(coordinate: $0.coordinate,
                               correction: 0,
                               name: $0.name)
            }
        }
                
        if let decodedWaypoints = decodedWaypoints {
            // The response lists the same number of tracepoints as the waypoints in the request, whether or not a given waypoint is leg-separating.
            waypoints = zip(decodedWaypoints, optionsWaypoints).map { (pair) -> Route.Waypoint in
                var (decodedWaypoint, waypointInOptions) = pair
                if let name = waypointInOptions.name?.nonEmptyString {
                    decodedWaypoint.name = name
                }
                return decodedWaypoint
            }
        } else {
            waypoints = decodedWaypoints
        }
        
        if let routes = try container.decodeIfPresent([Route].self, forKey: .routes) {
            // Postprocess each route.
            var legSeparators = waypoints?.compactMap { $0 }
            if let options = decoder.userInfo[.options] as? DirectionsOptions, let waypoints = waypoints {
                // Select first, last and all other waypoints which separate legs.
                var optionsLegSeparators = options.legSeparators
                legSeparators = zip(waypoints, options.waypoints).compactMap { (pair) -> Route.Waypoint? in
                    let (decodedWaypoint, waypointInOptions) = pair
                    if decodedWaypoint == waypoints.last! ||
                        decodedWaypoint == waypoints.first! {
                        return decodedWaypoint
                    }
                    
                    guard let index = optionsLegSeparators.firstIndex(of: waypointInOptions) else {
                        return nil
                    }
                    optionsLegSeparators.remove(at: index)
                    return decodedWaypoint
                }
            }
            
            for route in routes {
                route.routeIdentifier = identifier
                // Imbue each route’s legs with the waypoints refined above.
                if let legSeparators = legSeparators {
                    route.legSeparators = legSeparators
                }
            }
            self.routes = routes
        } else {
            routes = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(routes, forKey: .routes)
        try container.encodeIfPresent(waypoints, forKey: .waypoints)
    }

}
