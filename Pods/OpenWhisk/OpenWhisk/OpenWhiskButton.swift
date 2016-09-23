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

import UIKit

/*
 
 Convenience UI element that allows you to invoke whisk actions.  You can use like a normal UIButton and handle all the press events yourself, or you can have the button "self-contained".  If you set listenForPressEvents = true it will listen for its own press events and invoke the the configured action.
 
 */
@objc(WhiskButton) public class WhiskButton: UIButton {
    
    var whisk: Whisk?
    var urlSession: URLSession?
    
    var actionParameters: Dictionary<String,AnyObject>?
    var actionHasResult: Bool = false
    var actionName: String?
    var actionPackage: String?
    var actionNamespace: String?
    var isListeningToSelf: Bool?
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public var listenForPressEvents: Bool? {
        get {
            return isListeningToSelf
        }
        
        set {
            if newValue == true {
                self.addTarget(self, action: #selector(WhiskButton.buttonPressed), for: .touchUpInside)
            } else {
                self.removeTarget(self, action: #selector(WhiskButton.buttonPressed), for: .touchUpInside)
            }
            
            isListeningToSelf = newValue
        }
    }
    public var actionButtonCallback: ((Dictionary<String,AnyObject>?, WhiskError?) -> Void)?
    
    
    func buttonPressed() {
        invokeAction(parameters: nil, actionCallback: actionButtonCallback)
    }
    
    public func setupWhiskAction(qualifiedName qName:String, credentials: WhiskCredentials, hasResult: Bool = false,parameters: Dictionary<String, AnyObject>? = nil, urlSession: URLSession? = nil, baseUrl: String? = nil) throws {
        
        let pathParts = try Whisk.processQualifiedName(qName)
        
        setupWhiskAction(pathParts.name, package: pathParts.package, namespace: pathParts.namespace, credentials: credentials, hasResult: hasResult, parameters: parameters, urlSession: urlSession, baseUrl: baseUrl)
    }
    
    public func setupWhiskAction(_ name: String, package: String? = nil, namespace: String = "_", credentials: WhiskCredentials, hasResult: Bool = false,parameters: Dictionary<String, AnyObject>? = nil, urlSession: URLSession? = nil, baseUrl: String? = nil) {
        
        whisk = Whisk(credentials: credentials)
        
        if let session = urlSession {
            whisk?.urlSession = session
        }
        
        if let baseUrl = baseUrl {
            whisk?.baseURL = baseUrl
        }
        
        actionParameters = parameters
        actionName = name
        actionPackage = package
        actionNamespace = namespace
        actionHasResult = hasResult
    }
    
    public func invokeAction(parameters: [String:AnyObject]? = nil, actionCallback: ((Dictionary<String,AnyObject>?, WhiskError?) -> Void)?) {
        
        if let whisk = whisk, let actionName = actionName, let actionNamespace = actionNamespace {
            
            let queue = DispatchQueue(label:"com.ibm.mobilefirst.openwhisk.invokeAction")
            queue.async(qos: .userInitiated) {
                do {
                    
                    var params:[String:AnyObject]?
                    
                    if let parameters = parameters {
                        params = parameters
                    } else {
                        params = self.actionParameters
                    }
                    
                    try whisk.invokeAction(name: actionName, package: self.actionPackage, namespace: actionNamespace, parameters: params as AnyObject?, hasResult: self.actionHasResult, callback: {(reply, error) in
                        
                        
                        // note callback is in main queue already we should be on the UI thread
                        if let actionCallback = actionCallback {
                            actionCallback(reply, error)
                        }
                        
                        
                    })
                } catch {
                    print("Error invoking action: \(error)")
                }
            }
        } else {
            print("WhiskButton action not initialized")
        }
        
    }
    
}
