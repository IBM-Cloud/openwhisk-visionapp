/*
* Copyright 2015-2016 IBM Corporation
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation

/*

Hold the Whisk access key and access token.  The session token and jwtToken can be used to implement
custom authentication flows

*/
public struct WhiskCredentials {
    public init(accessKey: String?, accessToken: String?, sessionToken:String? = nil, jwtToken: String? = nil) {
        self.accessToken = accessToken
        self.accessKey = accessKey
        self.sessionToken = sessionToken
        self.jwtToken = jwtToken
    }
    
    // whisk credentials
    public var accessKey: String?
    public var accessToken: String?
    public var sessionToken: String?
    
    // optional app credentials
    public var appKey: String?
    public var appSecret: String?
    
    // optional token for custom authentication flow
    public var jwtToken: String?
}

/* Error types for Whisk calls */
public enum WhiskError: Error {
    case httpError(description: String, statusCode: Int) // something went wrong with the http call
    case jsonError(description: String) // json wasn't right
    case credentialError(description: String) // something is wrong with the whisk credentials
    case qualifiedNameFormat(description: String) // something is wrong in qualified name
    case whiskProcessingError(description: String, errorCode: Int) // something went wrong on the whisk side.
}

/* Type of Whisk operation requested */
enum WhiskType {
    case action
    case trigger
}

/* Main class to hold the calls to invoke Actions and fire Triggers */
public class Whisk {
    
    // Secrets needed to call Whisk API
    let AccessKey: String? // Whisk key
    let AccessToken: String? // Whisk token
    let AppKey: String? // application Key (currently not used)
    let AppSecret: String? // application Secret (curently not used)
    
    // api Host for Whisk backend
    public var whiskBaseURL: String?
    
    // set to non-nil if using a custom session
    public var urlSession: URLSession?
    
    public var verboseReplies: Bool = false
    
    // Set these if you want to run unit tests and mock
    // calls to Whisk backend.
    public var useMock: Bool = false
    public var mockReply: [String: AnyObject]?
    public var mockError: WhiskError?
    
    
    // return base URL of backend including common path for all API calls
    public var baseURL: String? {
        set {
            if let url = newValue {
                
                let c = url.characters.last
                
                let separater =  c == "/" ? "" : "/"
                
                whiskBaseURL = url + separater + "api/v1/"
                
            } else {
                whiskBaseURL = nil
            }
        }
        get {
            return whiskBaseURL
        }
    }
    
    // Initialize with credentials, region currently not used
    public init(credentials: WhiskCredentials, region: String = "US-East-1") {
        // initialize
        AccessKey = credentials.accessKey
        AccessToken = credentials.accessToken
        AppKey = credentials.appKey
        AppSecret = credentials.appSecret
        
    }
    
    
    /* Base function to fire Whisk Trigger identified by qualified name */
    public func fireTrigger(qualifiedName: String, parameters: AnyObject? = nil, callback: @escaping (Dictionary<String,AnyObject>?, WhiskError?)->Void) throws {
        
        let pathParts = try Whisk.processQualifiedName(qualifiedName)
        try fireTrigger(name: pathParts.name, package: pathParts.package, namespace: pathParts.namespace, parameters: parameters, callback: callback)
    }
    
    /* Base function to invoke Whisk Action identified by qualified name */
    public func invokeAction(qualifiedName: String, parameters: AnyObject?, hasResult: Bool = false, callback: @escaping (Dictionary<String,AnyObject>?, WhiskError?)->Void) throws {
        
        let pathParts = try Whisk.processQualifiedName(qualifiedName)
        try invokeAction(name: pathParts.name, package: pathParts.package, namespace: pathParts.namespace, parameters: parameters, hasResult: hasResult, callback: callback)
    }
    
    
    /* Base function to fire Whisk Trigger identified by components */
    public func fireTrigger(name: String, package: String? = nil, namespace: String = "_", parameters: AnyObject? = nil, callback: @escaping (Dictionary<String,AnyObject>?, WhiskError?)->Void) throws {
        
        if let accessKey = AccessKey, let accessToken = AccessToken {
            try httpRequestWhiskAPI(accessKey: accessKey, accessToken: accessToken, namespace: namespace, verb: "POST", type: .trigger, package: package, name:name, parameters: parameters, isSync: false, callback: { (jsonArray, error) in
                if let error = error {
                    callback(nil, error)
                } else {
                    callback(jsonArray, nil)
                }
            })
        } else {
            throw WhiskError.credentialError(description: "Access key and token not set")
        }
        
        
    }
    
    /* Base function to invoke Whisk Action identified by components */
    public func invokeAction(name: String, package: String? = nil, namespace: String = "_", parameters: AnyObject?, hasResult:Bool = false, callback: @escaping (Dictionary<String,AnyObject>?, WhiskError?)-> Void) throws {
        if let accessKey = AccessKey, let accessToken = AccessToken {
            
            try httpRequestWhiskAPI(accessKey: accessKey, accessToken: accessToken, namespace: namespace, verb: "POST", type: .action, package: package, name: name, parameters: parameters, isSync: hasResult, callback: {(jsonDict, error) in
                if let error = error {
                    callback(nil, error)
                } else {
                    callback(jsonDict, nil)
                }
                
            })
        } else {
            throw WhiskError.credentialError(description: "Access key and token not set")
        }
        
    }
    
    /* can redirect call here, e.g. if mocking */
    func httpRequestWhiskAPI(accessKey: String, accessToken: String, namespace: String, verb: String, type: WhiskType, package: String?, name: String, parameters: AnyObject?, isSync: Bool, callback: @escaping (Dictionary<String,AnyObject>?, WhiskError?) ->Void) throws {
        
        if useMock {
            callback(mockReply, mockError)
            
        } else {
            try whiskAPI(accessKey: accessKey, accessToken: accessToken, namespace: namespace, verb: verb, type: type, package: package, name: name, parameters: parameters, isSync: isSync, callback: callback)
        }
    }
    
    
    /* Network call */
    func whiskAPI(accessKey: String, accessToken: String, namespace: String, verb: String, type: WhiskType, package: String?, name: String, parameters: AnyObject?, isSync: Bool, callback:  @escaping (Dictionary<String,AnyObject>?,WhiskError?) ->Void) throws {
        
        // set parameters
        var paramsIsDict = false
        if let parameters = parameters {
            if parameters is Dictionary<String, AnyObject> {
                paramsIsDict = true
            }
        }
        
        // set authorization string
        let loginString = NSString(format: "%@:%@", accessKey, accessToken)
        let loginData: Data = loginString.data(using: String.Encoding.utf8.rawValue)!
        let base64LoginString = loginData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let typeStr: String!
        
        // set type
        switch type {
        case .action:
            typeStr = "actions"
        case .trigger:
            typeStr = "triggers"
        }
        
        // get base URL
        guard let actionURL = baseURL != nil ? baseURL : Config.getHostAndPath(type: typeStr) else {
            callback(nil, WhiskError.httpError(description: "Base URL not set, try using whisk.baseUrl setting", statusCode: 400))
            return
        }
        
        // append namespace and trigger/action path
        var syncName = "namespaces/"
        
        var namespaceStr = namespace
        
        if namespace.characters.count == 0 {
            namespaceStr = "_"
        }
        
        if let package = package {
            if package.characters.count == 0 {
                syncName = syncName + namespaceStr+"/"+typeStr+"/"+name
            } else {
                syncName = syncName + namespaceStr+"/"+typeStr+"/"+package+"/"+name
            }
        } else {
            syncName = syncName + namespaceStr+"/"+typeStr+"/"+name
        }
        
        // if action has results, specify as blocking
        if isSync == true {
            syncName += "?blocking=true"
        }
        
        // use this for verbose replies
        let restCall = actionURL+syncName
        
        guard let encodedPath = syncName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
            callback(nil, WhiskError.httpError(description: "URL Encode error \(syncName)", statusCode: 400))
            return
        }
        
        syncName = encodedPath
        
        // create request
        guard let url = URL(string:actionURL+syncName) else {
            // send back error on main queue
            
            callback(nil, WhiskError.httpError(description: "Malformed url \(actionURL+syncName)", statusCode: 400))
            
            return
            
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.httpMethod = verb
        
        // create JSON from parameters dictionary
        do {
            
            if let parameters = parameters {
                if paramsIsDict {
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions())
                } else {
                    if parameters is String {
                        let str = "{\"payload\":\"\(parameters as! String)\"}"
                        request.httpBody = str.data(using: String.Encoding.utf8)
                    } else {
                        let str = "{\"payload\": \(parameters)}"
                        request.httpBody = str.data(using: String.Encoding.utf8)
                    }
                }
            }
            
        } catch {
            print("Error parsing JSON in Whisk request: \(error)")
        }
        
        
        // retrieve session as default or use developer specified session
        let sess: URLSession!
        if let _ = urlSession {
            sess = urlSession
        } else {
            let sessConfig = URLSessionConfiguration.default
            sess = URLSession(configuration: sessConfig)
        }
        
        // perform network request
        let task = sess.dataTask(with: request) {
            data, response, error in
            let statusCode: Int!
            
            if let error = error {
                
                if let httpResponse = response as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                } else {
                    statusCode = -1
                }
                // return network transport error call on main queue
                DispatchQueue.main.async {
                    callback(nil, WhiskError.httpError(description: "\(error.localizedDescription)", statusCode: statusCode))
                }
                
                return
                
            } else {
                
                if let httpResponse = response as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                    do {
                        // success
                        if statusCode < 300 {
                            
                            switch verb {
                                // is an action invocation
                            case "POST":
                                var jsonDict = [String:AnyObject]()
                                
                                let respDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! Dictionary<String, AnyObject>
                                jsonDict = respDict
                                
                                
                                if let whiskError = jsonDict["error"] as? String {
                                    
                                    var errorCode = -1
                                    if let code = jsonDict["code"] as? Int {
                                        errorCode = code
                                    }
                                    // send back error on main queue
                                    DispatchQueue.main.async {
                                        callback(nil, WhiskError.whiskProcessingError(description: "errorCode:\(errorCode), \(whiskError)", errorCode: errorCode))
                                    }
                                    
                                } else {
                                    
                                    var whiskReply = [String:AnyObject]()
                                    
                                    if self.verboseReplies == true {
                                        whiskReply = jsonDict
                                        
                                        // add the rest call made to verbose replies for debugging
                                        switch type {
                                        case .action:
                                            whiskReply["actionUrl"] = restCall as AnyObject?
                                        case .trigger:
                                            whiskReply["triggerUrl"] = restCall as AnyObject?
                                        }
                                        
                                    } else {
                                        let reply = jsonDict
                                        whiskReply["activationId"] = reply["activationId"]
                                        
                                        if isSync == true {
                                            if let whiskResponse = reply["response"] as? [String:AnyObject] {
                                                
                                                if let actionResult = whiskResponse["result"] {
                                                    
                                                    //if let payload = actionResult["payload"] {
                                                    
                                                    let payload:AnyObject? = actionResult
                                                    if payload is String {
                                                        do {
                                                            
                                                           let payloadObj =  try JSONSerialization.jsonObject(with: (payload as! String).data(using: String.Encoding.utf8)!, options: [])
                                                           
                                                            whiskReply["result"] = payloadObj as AnyObject
                                                        } catch {
                                                            print("Error parsing payload into JSON, defaulting to string")
                                                            whiskReply = ["result" : "\(payload!)" as AnyObject]
                                                        }
                                                    } else {
                                                        whiskReply["result"] = payload as AnyObject
                                                    }
                                                    //}
                                                }
                                            }
                                        }
                                    }
                                    
                                    // send back successful response on main queue
                                    DispatchQueue.main.async {
                                        callback(whiskReply, nil)
                                    }
                                }
                                
                                // get info about actions/triggers
                                // not used right now
                            case "GET":
                                let jsonArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSArray
                                let jsonDict:Dictionary<String, AnyObject> = ["array":jsonArray]
                                
                                DispatchQueue.main.async {
                                    callback(jsonDict, nil)
                                }
                                
                            default:
                                break
                                
                            }
                        } else {
                            DispatchQueue.main.async {
                                callback(nil, WhiskError.httpError(description: "Whisk returned HTTP error code", statusCode: statusCode))
                            }
                        }
                        
                    } catch {
                        print("Error parsing JSON from Whisk response: \(error)")
                        DispatchQueue.main.async {
                            callback(nil, WhiskError.jsonError(description: "\(error)"))
                        }
                    }
                }
            }
        }
        
        task.resume()
        
        
    }
    
    /* Convert qualified name string into component parts of action or trigger call */
    class func processQualifiedName(_ qName: String) throws -> (namespace:String, package: String?, name: String) {
        var namespace = "_"
        var package: String? = nil
        var name = ""
        var doesSpecifyNamespace = false
        
        if qName.characters.first == "/" {
            doesSpecifyNamespace = true
        }
        
        let pathParts = qName.characters.split { $0 == "/" }.map(String.init)
        
        if doesSpecifyNamespace == true {
            if pathParts.count == 2 {
                namespace = pathParts[0]
                name = pathParts[1]
            } else if pathParts.count == 3 {
                namespace = pathParts[0]
                package = pathParts[1]
                name = pathParts[2]
            } else {
                throw WhiskError.qualifiedNameFormat(description: "Cannot parse \(qName)")
            }
        } else {
            if pathParts.count == 1 {
                name = pathParts[0]
            } else if pathParts.count == 2 {
                package = pathParts[0]
                name = pathParts[1]
            } else {
                throw WhiskError.qualifiedNameFormat(description: "Cannot parse \(qName)")
            }
        }
        
        return (namespace, package, name)
    }
    
}


