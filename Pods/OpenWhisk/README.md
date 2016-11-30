# Swift Client SDK for OpenWhisk
This is a Swift-based client SDK for OpenWhisk. You can use it to connect to the [IBM Bluemix OpenWhisk service](http://www.ibm.com/cloud-computing/bluemix/openwhisk/), or you own installation of [OpenWhisk](https://github.com/openwhisk/openwhisk).  It partially implements the OpenWhisk [REST API](https://github.com/openwhisk/openwhisk/blob/master/docs/reference.md#rest-api) and allows you to invoke actions and fire triggers. The client SDK is compatible with Swift 3.x and runs on iOS 9 & 10, WatchOS 3, and Darwin.  Since this code uses classes like URLSession, Linux support is linked to the current status of [Foundation on Linux](https://github.com/apple/swift-corelibs-foundation). 

## Installation
You can install the SDK using the source code in this repo, as a Cocoapod for iOS and WatchOS apps, Carthage, and as a package using the Swift Package Manager for Darwin CLI apps.

### Source Code Installation
To build the source code:
- Clone this repo.
- Open the `OpenWhisk.xcodeproj` file in Xcode 8.0
- Build the OpenWhisk target for an iOS app or the OpenWhiskWatch target for a WatchOS app.
- Locate the binary framework file (usually in `debug` or `release` directories at `~/Library/Developer/Xcode/DerivedData/$projectName-*`) and add it to the "Embedded Binaries" list in the General settings of your apps' target.

### CocoaPods Installation
The [official CocoaPods website](http://cocoapods.org) has detailed instructions on how to install and use CocoaPods.

The following lines in a Podfile will install the SDK for an iOS app with a watch OS extension: 

```
install! 'cocoapods', :deterministic_uuids => false
use_frameworks!

target 'MyApp' do
     pod 'OpenWhisk', :git => 'https://github.com/openwhisk/openwhisk-client-swift.git', :tag => '0.2.2'
end

target 'MyApp WatchKit Extension' do 
     pod 'OpenWhisk', :git => 'https://github.com/openwhisk/openwhisk-client-swift.git', :tag => '0.2.2'
end
```
You may get the warning 'target overrides the `EMBEDDED_CONTENT_CONTAINS_SWIFT` ' when you have a watch target.  You can eliminate this warning by changing this setting in "Build Settings" to the value '$(inherited)'.

After installation, open your project workspace.  You may get the following warning when building:
`Use Legacy Swift Language Version” (SWIFT_VERSION) is required to be configured correctly for targets which use Swift. Use the [Edit > Convert > To Current Swift Syntax…] menu to choose a Swift version or use the Build Settings editor to configure the build setting directly.`
This is caused if Cocoapods does not update the Swift version in the Pods project.  To fix, select the Pods project and the OpenWhisk target.  Go to Build Settings and change the setting `Use Legacy Swift Language Version` to `no`. You can also add the following post installation instructions at the end of you Podfile:

```
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end
```

### Carthage Installation

Visit the [official Carthage site on Github](https://github.com/Carthage/Carthage) for detailed instructions on installing and using Carthage.

Here is an example Cartfile for iOS installation using Carthage:  

```
github "openwhisk/openwhisk-client-swift.git" ~> 0.2.2 # Or latest version

```

### Swift Package Manager
Use the Swift Package Manager to install into a Darwin CLI app.  Below is an example Package.swift manifest file you can use:

```
import PackageDescription

let package = Package(
  name:  "PackageTest",
  dependencies: [
    .Package(url:  "https://github.com/openwhisk/openwhisk-client-swift.git", versions: Version(0,0,0)..<Version(1,0,0)),
  ]
)
```

## Usage

To get up and running quickly, create a WhiskCredentials object with your OpenWhisk API credentials and create a Whisk instance from that.

You create a credentials object as:

```
let credentialsConfiguration = WhiskCredentials(accessKey: "myKey", accessToken: "myToken")

let whisk = Whisk(credentials: credentialsConfiguration!)
```

You can retrieve the key and token with the following CLI command:

```
wsk property get --auth
```

```
whisk auth              kkkkkkkk-kkkk-kkkk-kkkk-kkkkkkkkkkkk:tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt
```

The strings before and after the colon are your key and token, respectively.

### Invoke an OpenWhisk Action
Call "invokeAction" with the action name to invoke a remote action. You can specify the namespace the action belongs to, or just leave it blank to accept the default namespace.  Use a dictionary to pass parameters to the action as required.

```swift
// In this example, we are invoking an action to print a message to the OpenWhisk Console
var params = Dictionary<String, String>()
params["payload"] = "Hi from mobile"

do {
    try whisk.invokeAction(name: "helloConsole", package: "mypackage", namespace: "mynamespace", parameters: params, hasResult: false, callback: {(reply, error) -> Void in 
        if let error = error {
            //do something
            print("Error invoking action \(error.localizedDescription)")
        } else {
            print("Action invoked!")
        }
        
    })
} catch {
    print("Error \(error)")
}
```

In the above example, we are invoking the "helloConsole" action using the default namespace. 

### Fire an OpenWhisk Trigger
To fire a remote OpenWhisk trigger, call the "fireTrigger" method.  Pass in parameters as required using a dictionary.

```swift
// In this example we are firing a trigger when our location has changed by a certain amount

var locationParams = Dictionary<String, String>()
locationParams["payload"] = "{\"lat\":41.27093, \"lon\":-73.77763}"

do {
    try whisk.fireTrigger(name: "locationChanged", package: "mypackage", namespace: "mynamespace", parameters: locationParams, callback: {(reply, error) -> Void in
        
        if let error = error {
            print("Error firing trigger \(error.localizedDescription)")
        } else {
            print("Trigger fired!")
        }
    })
} catch {
    print("Error \(error)")
}
```
In the above example, we are firing a trigger "locationChanged".

### Actions that return a result
If the action returns a result, set hasResult to true in the invokeAction call. The result of the action is returned in the reply dictionary, for example:

```swift
do {
    try whisk.invokeAction(name: "actionWithResult", package: "mypackage", namespace: "mynamespace", parameters: params, hasResult: true, callback: {(reply, error) -> Void in
        
        if let error = error {
            //do something
            print("Error invoking action \(error.localizedDescription)")
            
        } else {
            var result = reply["result"]
            print("Got result \(result)")
        }
        
        
    })
} catch {
    print("Error \(error)")
}
```
By default, the SDK will only return the activationId and any result produced by the invoked action.  To get metadata of the entire response object, which includes the HTTP response status code and the REST API URL the SDK tried to call, use this setting:

```
whisk.verboseReplies = true
```

The REST API URL called will be in the actionUrl/triggerUrl fields of the response.

## SDK configuration

You can configure the SDK to work with different installations of OpenWhisk using the baseURL parameter. For instance:

```swift
whisk.baseURL = "http://localhost:8080"
```
will use an OpenWhisk running at localhost:8080.  If you do not specify the baseUrl, the Mobile SDK will use the instance running at https://openwhisk.ng.bluemix.net

You can pass in a custom URLSession in case you require special network handling.  For example, you may have your own OpenWhisk installation that uses self-signed certificates:

```swift

// create a network delegate that trusts everything
class NetworkUtilsDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

// create an URLSession that uses the trusting delegate
let session = URLSession(configuration: URLSessionConfiguration.default, delegate: NetworkUtilsDelegate(), delegateQueue:OperationQueue.main)

// set the SDK to use this urlSession instead of the default shared one
whisk.urlSession = session
```
#### Support for Qualified Names
All actions and triggers have a fully qualified name which is made up of a namespace, a package, and an action/trigger name. The SDK can accept these as parameters when invoking an action or firing a trigger. The SDK also provides a function that accepts a fully qualified name that looks like "/mynamespace/mypackage/nameOfActionOrTrigger". The qualified name string supports unnamed default values for namespaces and packages that all OpenWhisk users have, so the following parsing rules apply:

1. qName = "foo" will result in namespace = default, package = default, action/trigger = "foo"
2. qName = "mypackage/foo" will result in namespace = default, package = mypackage, action/trigger = "foo"
3. qName = "/mynamespace/foo" will result in namespace = mynamespace, package = default, action/trigger = "foo"
4. qName = "/mynamespace/mypackage/foo will result in namespace = mynamespace, package = mypackage, action/trigger = "foo" 

All other combinations will throw a WhiskError.QualifiedName error. When using qualified names, you must wrap the call in a do/try/catch block.

#### SDK Button
For convenience, the iOS version of the SDK includes a WhiskButton, which extends the UIButton to allow it to invoke OpenWhisk actions.  To use this:

```swift
var whiskButton = WhiskButton(frame: CGRectMake(0,0,20,20))

whiskButton.setupWhiskAction("helloConsole", package: "mypackage", namespace: "_", credentials: credentialsConfiguration!, hasResult: false, parameters: nil, urlSession: nil)

let myParams = ["name":"value"]

// Call this when you detect a press event, e.g. in an IBAction, to invoke the action 
whiskButton.invokeAction(parameters: myParams, callback: { reply, error in
    if let error = error {
        print("Oh no, error: \(error)")
    } else {
        print("Success: \(reply)")
    }
})

// or alternatively you can setup a "self contained" button that listens for press events on itself and invokes an action

var whiskButtonSelfContained = WhiskButton(frame: CGRectMake(0,0,20,20))
whiskButtonSelfContained.listenForPressEvents = true
do { 

   // use qualified name API which requires do/try/catch
   try whiskButtonSelfContained.setupWhiskAction("mypackage/helloConsole", credentials: credentialsConfiguration!, hasResult: false, parameters: nil, urlSession: nil)
   whiskButtonSelfContained.actionButtonCallback = { reply, error in

       if let error = error {
           print("Oh no, error: \(error)")
       } else {
           print("Success: \(reply)")
       }
   }
} catch {
   print("Error setting up button \(error)")
}

```

