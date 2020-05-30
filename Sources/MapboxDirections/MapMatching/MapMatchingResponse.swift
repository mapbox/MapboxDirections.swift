import Foundation

public struct MapMatchingResponse {

    public let httpResponse: HTTPURLResponse?
    
    public var matches : [Match]?
    public var tracepoints: [Match.Tracepoint?]?
    
    public let options: MatchOptions
    public let credentials: DirectionsCredentials
    
    /**
     The time when this `MapMatchingResponse` object was created, which is immediately upon recieving the raw URL response.
     
     If you manually start fetching a task returned by `Directions.url(forCalculating:)`, this property is set to `nil`; use the `URLSessionTaskTransactionMetrics.responseEndDate` property instead. This property may also be set to `nil` if you create this result from a JSON object or encoded object.
     
     This property does not persist after encoding and decoding.
     */
    public var created: Date = Date()
}

extension MapMatchingResponse: Codable {
    private enum CodingKeys: String, CodingKey {
        case matches = "matchings"
        case tracepoints
    }

     public init(httpResponse: HTTPURLResponse?, matches: [Match]? = nil, tracepoints: [Match.Tracepoint]? = nil, options: MatchOptions, credentials: DirectionsCredentials) {
        self.httpResponse = httpResponse
        self.matches = matches
        self.tracepoints = tracepoints
        self.options = options
        self.credentials = credentials
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.httpResponse = decoder.userInfo[.httpResponse] as? HTTPURLResponse
        
        guard let options = decoder.userInfo[.options] as? MatchOptions else {
            throw DirectionsCodingError.missingOptions
        }
        
        self.options = options
        
        guard let credentials = decoder.userInfo[.credentials] as? DirectionsCredentials else {
            throw DirectionsCodingError.missingCredentials
        }
        self.credentials = credentials
        
        tracepoints = try container.decodeIfPresent([Match.Tracepoint?].self, forKey: .tracepoints)
        matches = try container.decodeIfPresent([Match].self, forKey: .matches)
        
        if let sortedTracepoints = self.tracepoints?.sorted(by: {
            ($0?.waypointIndex ?? -1) < ($1?.waypointIndex ?? -1)
        }) {
            matches?.enumerated().forEach { (index, element) in
                element.tracepoints = sortedTracepoints.filter {
                    $0?.matchingIndex == index
                }
            }
        }
    }
}
