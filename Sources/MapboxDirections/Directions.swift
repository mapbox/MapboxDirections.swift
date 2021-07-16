import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

typealias JSONDictionary = [String: Any]

/// Indicates that an error occurred in MapboxDirections.
public let MBDirectionsErrorDomain = "com.mapbox.directions.ErrorDomain"


/// The user agent string for any HTTP requests performed directly within this library.
let userAgent: String = {
    var components: [String] = []
    
    if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        components.append("\(appName)/\(version)")
    }
    
    let libraryBundle: Bundle? = Bundle(for: Directions.self)
    
    if let libraryName = libraryBundle?.infoDictionary?["CFBundleName"] as? String, let version = libraryBundle?.infoDictionary?["CFBundleShortVersionString"] as? String {
        components.append("\(libraryName)/\(version)")
    }
    
    // `ProcessInfo().operatingSystemVersionString` can replace this when swift-corelibs-foundaton is next released:
    // https://github.com/apple/swift-corelibs-foundation/blob/main/Sources/Foundation/ProcessInfo.swift#L104-L202
    let system: String
    #if os(macOS)
        system = "macOS"
    #elseif os(iOS)
        system = "iOS"
    #elseif os(watchOS)
        system = "watchOS"
    #elseif os(tvOS)
        system = "tvOS"
    #elseif os(Linux)
        system = "Linux"
    #else
        system = "unknown"
    #endif
    let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
    components.append("\(system)/\(systemVersion.majorVersion).\(systemVersion.minorVersion).\(systemVersion.patchVersion)")
    
    let chip: String
    #if arch(x86_64)
        chip = "x86_64"
    #elseif arch(arm)
        chip = "arm"
    #elseif arch(arm64)
        chip = "arm64"
    #elseif arch(i386)
        chip = "i386"
    #else
        // Maybe fall back on `uname(2).machine`?
        chip = "unrecognized"
    #endif
    components.append("(\(chip))")
    
    return components.joined(separator: " ")
}()

/**
 A `Directions` object provides you with optimal directions between different locations, or waypoints. The directions object passes your request to the [Mapbox Directions API](https://docs.mapbox.com/api/navigation/#directions) and returns the requested information to a closure (block) that you provide. A directions object can handle multiple simultaneous requests. A `RouteOptions` object specifies criteria for the results, such as intermediate waypoints, a mode of transportation, or the level of detail to be returned.
 
 Each result produced by the directions object is stored in a `Route` object. Depending on the `RouteOptions` object you provide, each route may include detailed information suitable for turn-by-turn directions, or it may include only high-level information such as the distance, estimated travel time, and name of each leg of the trip. The waypoints that form the request may be conflated with nearby locations, as appropriate; the resulting waypoints are provided to the closure.
 */
open class Directions: NSObject {
    
    /**
     A tuple type representing the direction session that was generated from the request.
     
     - parameter options: A `DirectionsOptions ` object representing the request parameter options.
     
     - parameter credentials: A object containing the credentials used to make the request.
     */
    public typealias Session = (options: DirectionsOptions, credentials: DirectionsCredentials)
    
    /**
     A closure (block) to be called when a directions request is complete.
     
     - parameter session: A `Directions.Session` object containing session information
     
     - parameter result: A `Result` enum that represents the `RouteResponse` if the request returned successfully, or the error if it did not.
     */
    public typealias RouteCompletionHandler = (_ session: Session, _ result: Result<RouteResponse, DirectionsError>) -> Void
    
    /**
     A closure (block) to be called when a map matching request is complete.
     
     - parameter session: A `Directions.Session` object containing session information
     
     - parameter result: A `Result` enum that represents the `MapMatchingResponse` if the request returned successfully, or the error if it did not.
     */
    public typealias MatchCompletionHandler = (_ session: Session, _ result: Result<MapMatchingResponse, DirectionsError>) -> Void
    
    /**
     A closure (block) to be called when a directions refresh request is complete.
     
     - parameter credentials: An object containing the credentials used to make the request.
     - parameter result: A `Result` enum that represents the `RouteRefreshResponse` if the request returned successfully, or the error if it did not.
     
     - postcondition: To update the original route, pass `RouteRefreshResponse.route` into the `Route.refreshLegAttributes(from:)` method.
     */
    public typealias RouteRefreshCompletionHandler = (_ credentials: DirectionsCredentials, _ result: Result<RouteRefreshResponse, DirectionsError>) -> Void
    
    // MARK: Creating a Directions Object
    
    /**
     The shared directions object.
     
     To use this object, a Mapbox [access token](https://docs.mapbox.com/help/glossary/access-token/) should be specified in the `MBXAccessToken` key in the main application bundle’s Info.plist.
     */
    public static let shared = Directions()

    /**
     The Authorization & Authentication credentials that are used for this service.
     
     If nothing is provided, the default behavior is to read credential values from the developer's Info.plist.
     */
    public let credentials: DirectionsCredentials
    
    /**
     Initializes a newly created directions object with an optional access token and host.
     
     - parameter credentials: A `DirectionsCredentials` object that, optionally, contains customized Token and Endpoint information. If no credentials object is supplied, then defaults are used.
     */
    
    public init(credentials:  DirectionsCredentials = .init()) {
        self.credentials = credentials
    }
    
    
    // MARK: Getting Directions
    
    /**
     Begins asynchronously calculating routes using the given options and delivers the results to a closure.
     
     This method retrieves the routes asynchronously from the [Mapbox Directions API](https://www.mapbox.com/api-documentation/navigation/#directions) over a network connection. If a connection error or server error occurs, details about the error are passed into the given completion handler in lieu of the routes.
     
     Routes may be displayed atop a [Mapbox map](https://www.mapbox.com/maps/).
     
     - parameter options: A `RouteOptions` object specifying the requirements for the resulting routes.
     - parameter completionHandler: The closure (block) to call with the resulting routes. This closure is executed on the application’s main thread.
     - returns: The data task used to perform the HTTP request. If, while waiting for the completion handler to execute, you no longer want the resulting routes, cancel this task.
     */
    @discardableResult open func calculate(_ options: RouteOptions, completionHandler: @escaping RouteCompletionHandler) -> URLSessionDataTask {
        options.fetchStartDate = Date()
        let session = (options: options as DirectionsOptions, credentials: self.credentials)
        let request = urlRequest(forCalculating: options)
        let requestTask = URLSession.shared.dataTask(with: request) { (possibleData, possibleResponse, possibleError) in
            
            if let urlError = possibleError as? URLError {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.network(urlError)))
                }
                return
            }
            
            guard let response = possibleResponse, ["application/json", "text/html"].contains(response.mimeType) else {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.invalidResponse(possibleResponse)))
                }
                return
            }
            
            guard let data = possibleData else {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.noData))
                }
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decoder = JSONDecoder()
                    decoder.userInfo = [.options: options,
                                        .credentials: self.credentials]
                    
                    guard let disposition = try? decoder.decode(ResponseDisposition.self, from: data) else {
                        let apiError = DirectionsError(code: nil, message: nil, response: possibleResponse, underlyingError: possibleError)

                        DispatchQueue.main.async {
                            completionHandler(session, .failure(apiError))
                        }
                        return
                    }
                    
                    guard (disposition.code == nil && disposition.message == nil) || disposition.code == "Ok" else {
                        let apiError = DirectionsError(code: disposition.code, message: disposition.message, response: response, underlyingError: possibleError)
                        DispatchQueue.main.async {
                            completionHandler(session, .failure(apiError))
                        }
                        return
                    }
                    
                    let result = try decoder.decode(RouteResponse.self, from: data)
                    guard result.routes != nil else {
                        DispatchQueue.main.async {
                            completionHandler(session, .failure(.unableToRoute))
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        completionHandler(session, .success(result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        let bailError = DirectionsError(code: nil, message: nil, response: response, underlyingError: error)
                        completionHandler(session, .failure(bailError))
                    }
                }
            }
        }
        requestTask.priority = 1
        requestTask.resume()
        
        return requestTask
    }
    
    /**
     Begins asynchronously calculating matches using the given options and delivers the results to a closure.
     
     This method retrieves the matches asynchronously from the [Mapbox Map Matching API](https://docs.mapbox.com/api/navigation/#map-matching) over a network connection. If a connection error or server error occurs, details about the error are passed into the given completion handler in lieu of the routes.
     
     To get `Route`s based on these matches, use the `calculateRoutes(matching:completionHandler:)` method instead.
     
     - parameter options: A `MatchOptions` object specifying the requirements for the resulting matches.
     - parameter completionHandler: The closure (block) to call with the resulting matches. This closure is executed on the application’s main thread.
     - returns: The data task used to perform the HTTP request. If, while waiting for the completion handler to execute, you no longer want the resulting matches, cancel this task.
     */
    @discardableResult open func calculate(_ options: MatchOptions, completionHandler: @escaping MatchCompletionHandler) -> URLSessionDataTask {
        options.fetchStartDate = Date()
        let session = (options: options as DirectionsOptions, credentials: self.credentials)
        let request = urlRequest(forCalculating: options)
        let requestTask = URLSession.shared.dataTask(with: request) { (possibleData, possibleResponse, possibleError) in
            
            if let urlError = possibleError as? URLError {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.network(urlError)))
                }
                return
            }
            
            guard let response = possibleResponse, response.mimeType == "application/json" else {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.invalidResponse(possibleResponse)))
                    
                }
                return
            }
            
            guard let data = possibleData else {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.noData))
                }
                return
            }
            
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decoder = JSONDecoder()
                    decoder.userInfo = [.options: options,
                                        .credentials: self.credentials]
                    guard let disposition = try? decoder.decode(ResponseDisposition.self, from: data) else {
                          let apiError = DirectionsError(code: nil, message: nil, response: possibleResponse, underlyingError: possibleError)
                          DispatchQueue.main.async {
                            completionHandler(session, .failure(apiError))
                          }
                          return
                      }
                      
                      guard disposition.code == "Ok" else {
                          let apiError = DirectionsError(code: disposition.code, message: disposition.message, response: response, underlyingError: possibleError)
                          DispatchQueue.main.async {
                            completionHandler(session, .failure(apiError))
                          }
                          return
                      }
                    
                    let response = try decoder.decode(MapMatchingResponse.self, from: data)
                    
                    guard response.matches != nil else {
                        DispatchQueue.main.async {
                            completionHandler(session, .failure(.unableToRoute))
                        }
                        return
                    }
                                        
                    DispatchQueue.main.async {
                        completionHandler(session, .success(response))
                    }
                } catch {
                    DispatchQueue.main.async {
                        let caughtError = DirectionsError.unknown(response: response, underlying: error, code: nil, message: nil)
                        completionHandler(session, .failure(caughtError))
                    }
                }
            }
        }
        requestTask.priority = 1
        requestTask.resume()
        
        return requestTask
    }
    
    /**
     Begins asynchronously calculating routes that match the given options and delivers the results to a closure.
     
     This method retrieves the routes asynchronously from the [Mapbox Map Matching API](https://docs.mapbox.com/api/navigation/#map-matching) over a network connection. If a connection error or server error occurs, details about the error are passed into the given completion handler in lieu of the routes.
     
     To get the `Match`es that these routes are based on, use the `calculate(_:completionHandler:)` method instead.
     
     - parameter options: A `MatchOptions` object specifying the requirements for the resulting match.
     - parameter completionHandler: The closure (block) to call with the resulting routes. This closure is executed on the application’s main thread.
     - returns: The data task used to perform the HTTP request. If, while waiting for the completion handler to execute, you no longer want the resulting routes, cancel this task.
     */
    @discardableResult open func calculateRoutes(matching options: MatchOptions, completionHandler: @escaping RouteCompletionHandler) -> URLSessionDataTask {
        options.fetchStartDate = Date()
        let session = (options: options as DirectionsOptions, credentials: self.credentials)
        let request = urlRequest(forCalculating: options)
        let requestTask = URLSession.shared.dataTask(with: request) { (possibleData, possibleResponse, possibleError) in
            
             if let urlError = possibleError as? URLError {
                 DispatchQueue.main.async {
                    completionHandler(session, .failure(.network(urlError)))
                 }
                 return
             }
            
            guard let response = possibleResponse, ["application/json", "text/html"].contains(response.mimeType) else  {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.invalidResponse(possibleResponse)))
                }
                return
            }
            
            guard let data = possibleData else {
                DispatchQueue.main.async {
                    completionHandler(session, .failure(.noData))
                }
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decoder = JSONDecoder()
                    decoder.userInfo = [.options: options,
                                        .credentials: self.credentials]
                    
                    
                    guard let disposition = try? decoder.decode(ResponseDisposition.self, from: data) else {
                        let apiError = DirectionsError(code: nil, message: nil, response: possibleResponse, underlyingError: possibleError)
                        DispatchQueue.main.async {
                            completionHandler(session, .failure(apiError))
                        }
                        return
                    }
                    
                    guard disposition.code == "Ok" else {
                        let apiError = DirectionsError(code: disposition.code, message: disposition.message, response: response, underlyingError: possibleError)
                        DispatchQueue.main.async {
                            completionHandler(session, .failure(apiError))
                        }
                        return
                    }
                    
                    let result = try decoder.decode(MapMatchingResponse.self, from: data)
                    
                    let routeResponse = try RouteResponse(matching: result, options: options, credentials: self.credentials)
                    guard routeResponse.routes != nil else {
                        DispatchQueue.main.async {
                            completionHandler(session, .failure(.unableToRoute))
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        completionHandler(session, .success(routeResponse))
                    }
                } catch {
                    DispatchQueue.main.async {
                        let bailError = DirectionsError(code: nil, message: nil, response: response, underlyingError: error)
                        completionHandler(session, .failure(bailError))
                    }
                }
            }
        }
        requestTask.priority = 1
        requestTask.resume()
        
        return requestTask
    }
    
    /**
     Begins asynchronously refreshing the route with the given identifier, optionally starting from an arbitrary leg along the route.
     
     This method retrieves skeleton route data asynchronously from the Mapbox Directions Refresh API over a network connection. If a connection error or server error occurs, details about the error are passed into the given completion handler in lieu of the routes.
     
     - precondition: Set `RouteOptions.refreshingEnabled` to `true` when calculating the original route.
     
     - parameter responseIdentifier: The `RouteResponse.identifier` value of the `RouteResponse` that contains the route to refresh.
     - parameter routeIndex: The index of the route to refresh in the original `RouteResponse.routes` array.
     - parameter startLegIndex: The index of the leg in the route at which to begin refreshing. The response will omit any leg before this index and refresh any leg from this index to the end of the route. If this argument is omitted, the entire route is refreshed.
     - parameter completionHandler: The closure (block) to call with the resulting skeleton route data. This closure is executed on the application’s main thread.
     - returns: The data task used to perform the HTTP request. If, while waiting for the completion handler to execute, you no longer want the resulting skeleton routes, cancel this task.
     */
    @discardableResult open func refreshRoute(responseIdentifier: String, routeIndex: Int, fromLegAtIndex startLegIndex: Int = 0, completionHandler: @escaping RouteRefreshCompletionHandler) -> URLSessionDataTask? {

        let request = urlRequest(forRefreshing: responseIdentifier, routeIndex: routeIndex, fromLegAtIndex: startLegIndex)
        let requestTask = URLSession.shared.dataTask(with: request) { (possibleData, possibleResponse, possibleError) in
            if let urlError = possibleError as? URLError {
                DispatchQueue.main.async {
                    completionHandler(self.credentials, .failure(.network(urlError)))
                }
                return
            }
            
            guard let response = possibleResponse, ["application/json", "text/html"].contains(response.mimeType) else {
                DispatchQueue.main.async {
                    completionHandler(self.credentials, .failure(.invalidResponse(possibleResponse)))
                }
                return
            }
            
            guard let data = possibleData else {
                DispatchQueue.main.async {
                    completionHandler(self.credentials, .failure(.noData))
                }
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decoder = JSONDecoder()
                    decoder.userInfo = [
                        .responseIdentifier: responseIdentifier,
                        .routeIndex: routeIndex,
                        .startLegIndex: startLegIndex,
                        .credentials: self.credentials,
                    ]
                    
                    guard let disposition = try? decoder.decode(ResponseDisposition.self, from: data) else {
                        let apiError = DirectionsError(code: nil, message: nil, response: possibleResponse, underlyingError: possibleError)

                        DispatchQueue.main.async {
                            completionHandler(self.credentials, .failure(apiError))
                        }
                        return
                    }
                    
                    guard (disposition.code == nil && disposition.message == nil) || disposition.code == "Ok" else {
                        let apiError = DirectionsError(code: disposition.code, message: disposition.message, response: response, underlyingError: possibleError)
                        DispatchQueue.main.async {
                            completionHandler(self.credentials, .failure(apiError))
                        }
                        return
                    }
                    
                    let result = try decoder.decode(RouteRefreshResponse.self, from: data)
                    
                    DispatchQueue.main.async {
                        completionHandler(self.credentials, .success(result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        let bailError = DirectionsError(code: nil, message: nil, response: response, underlyingError: error)
                        completionHandler(self.credentials, .failure(bailError))
                    }
                }
            }
        }
        requestTask.priority = 1
        requestTask.resume()
        return requestTask
    }
    
    open func urlRequest(forRefreshing responseIdentifier: String, routeIndex: Int, fromLegAtIndex startLegIndex: Int) -> URLRequest {
        var params: [URLQueryItem] = []
        params += [URLQueryItem(name: "access_token", value: credentials.accessToken)]
        
        var unparameterizedURL = URL(string: "directions-refresh/v1/\(DirectionsProfileIdentifier.automobileAvoidingTraffic.rawValue)", relativeTo: credentials.host)!
        unparameterizedURL.appendPathComponent(responseIdentifier)
        unparameterizedURL.appendPathComponent(String(routeIndex))
        unparameterizedURL.appendPathComponent(String(startLegIndex))
        var components = URLComponents(url: unparameterizedURL, resolvingAgainstBaseURL: true)!
        components.queryItems = params
        
        let getURL = components.url!
        var request = URLRequest(url: getURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
    /**
     The GET HTTP URL used to fetch the routes from the API.
     
     After requesting the URL returned by this method, you can parse the JSON data in the response and pass it into the `Route.init(json:waypoints:profileIdentifier:)` initializer. Alternatively, you can use the `calculate(_:options:)` method, which automatically sends the request and parses the response.
     
     - parameter options: A `DirectionsOptions` object specifying the requirements for the resulting routes.
     - returns: The URL to send the request to.
     */
    open func url(forCalculating options: DirectionsOptions) -> URL {
        return url(forCalculating: options, httpMethod: "GET")
    }
    
    /**
     The HTTP URL used to fetch the routes from the API using the specified HTTP method.
     
     The query part of the URL is generally suitable for GET requests. However, if the URL is exceptionally long, it may be more appropriate to send a POST request to a URL without the query part, relegating the query to the body of the HTTP request. Use the `urlRequest(forCalculating:)` method to get an HTTP request that is a GET or POST request as necessary.
     
     After requesting the URL returned by this method, you can parse the JSON data in the response and pass it into the `Route.init(json:waypoints:profileIdentifier:)` initializer. Alternatively, you can use the `calculate(_:options:)` method, which automatically sends the request and parses the response.
     
     - parameter options: A `DirectionsOptions` object specifying the requirements for the resulting routes.
     - parameter httpMethod: The HTTP method to use. The value of this argument should match the `URLRequest.httpMethod` of the request you send. Currently, only GET and POST requests are supported by the API.
     - returns: The URL to send the request to.
     */
    open func url(forCalculating options: DirectionsOptions, httpMethod: String) -> URL {
        let includesQuery = httpMethod != "POST"
        var params = (includesQuery ? options.urlQueryItems : [])
        params += [URLQueryItem(name: "access_token", value: credentials.accessToken)]
        
        if let skuToken = credentials.skuToken {
            params += [URLQueryItem(name: "sku", value: skuToken)]
        }
        
        let unparameterizedURL = URL(string: includesQuery ? options.path : options.abridgedPath, relativeTo: credentials.host)!
        var components = URLComponents(url: unparameterizedURL, resolvingAgainstBaseURL: true)!
        components.queryItems = params
        return components.url!
    }
    
    /**
     The HTTP request used to fetch the routes from the API.
     
     The returned request is a GET or POST request as necessary to accommodate URL length limits.
     
     After sending the request returned by this method, you can parse the JSON data in the response and pass it into the `Route.init(json:waypoints:profileIdentifier:)` initializer. Alternatively, you can use the `calculate(_:options:)` method, which automatically sends the request and parses the response.
     
     - parameter options: A `DirectionsOptions` object specifying the requirements for the resulting routes.
     - returns: A GET or POST HTTP request to calculate the specified options.
     */
    open func urlRequest(forCalculating options: DirectionsOptions) -> URLRequest {
        let getURL = self.url(forCalculating: options, httpMethod: "GET")
        var request = URLRequest(url: getURL)
        if getURL.absoluteString.count > MaximumURLLength {
            request.url = url(forCalculating: options, httpMethod: "POST")
            
            let body = options.httpBody.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            request.httpBody = body
        }
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}

/**
    Keys to pass to populate a `userInfo` dictionary, which is passed to the `JSONDecoder` upon trying to decode a `RouteResponse`, `MapMatchingResponse`or `RouteRefreshResponse`.
 */
public extension CodingUserInfoKey {
    static let options = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.routeOptions")!
    static let httpResponse = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.httpResponse")!
    static let credentials = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.credentials")!
    static let tracepoints = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.tracepoints")!
    
    static let responseIdentifier = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.responseIdentifier")!
    static let routeIndex = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.routeIndex")!
    static let startLegIndex = CodingUserInfoKey(rawValue: "com.mapbox.directions.coding.startLegIndex")!
}
