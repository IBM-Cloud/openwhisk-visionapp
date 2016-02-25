/**
 * Copyright 2016 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the “License”);
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an “AS IS” BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import UIKit
import Alamofire
import SwiftyJSON
import OpenWhisk

/**
 * Processes images with IBM Bluemix OpenWhisk
 */
class ServerlessAPI {
  
  // TODO: Change to your Cloudant credentials url
  let CloudantUrl = "https://username:password@host.cloudant.com"
  let CloudantDbName = "openwhisk-vision"
  
  // TODO: Change YOUR_NAMESPACE to the namespace where the vision-analysis action was created
  // You can get the value with "wsk property get --namespace"
  let ActionNamespace = "YOUR_NAMESPACE"
  let ActionName = "vision-analysis"
  
  // TODO: Put your OpenWhisk key and token here
  // You can obtain the values at https://new-console.ng.bluemix.net/openwhisk/sdk/ios
  let WhiskAppKey = ""
  let WhiskAppSecret = ""
  
  /**
   * Processes an image.
   *
   * - image: the image to analyze
   * - onProgress: called while the image is being sent for processing
   * - onSuccess: called when results have been returned
   * - onFailure: called if there was an error processing the image
   */
  func process(image: UIImage, onProgress: (phase: String, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void, onSuccess: (Result) -> Void, onFailure: () -> Void) {
    createDocument(image, onProgress: onProgress, onSuccess: onSuccess, onFailure: onFailure)
  }
  
  /// Step 1 - Create a new document in Cloudant
  private func createDocument(image: UIImage, onProgress: (phase: String, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void, onSuccess: (Result) -> Void, onFailure: () -> Void) {
    print("Creating temporary image document...")
    Alamofire.request(.POST, "\(CloudantUrl)/\(CloudantDbName)", parameters: [ "type": "temp-image" ], encoding: .JSON)
      .responseJSON { (response) -> Void in
        switch (response.result) {
        case .Success:
          let result = JSON(data: response.data!)
          print("Document created", result)
          self.attachImage(result["id"].string!, documentRev: result["rev"].string!,
            image: image, onProgress: onProgress, onSuccess: onSuccess, onFailure: onFailure)
        case .Failure:
          onFailure()
        }
    }
  }
  
  /// Step 2 - Attach the image to the document
  private func attachImage(documentId: String, documentRev: String, image: UIImage, onProgress: (phase: String, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void, onSuccess: (Result) -> Void, onFailure: () -> Void) {
    print("Attaching image to document", documentId, documentRev)
    
    let imageData = UIImageJPEGRepresentation(image, 0.3)
    Alamofire.upload(
      .PUT,
      "\(CloudantUrl)/\(CloudantDbName)/\(documentId)/image.jpg?rev=\(documentRev)",
      data: imageData!)
      .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
        onProgress(phase: "Uploading...", bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
      }
      .responseJSON { (response) -> Void in
        switch (response.result) {
        case .Success:
          let result = JSON(data: response.data!)
          print("Image uploaded", result)
          self.analyze(result["id"].string!, documentRev: result["rev"].string!, onSuccess: onSuccess, onFailure: onFailure)
        case .Failure:
          onFailure()
        }
    }
  }
  
  /// Step 3 - Analyze the image with OpenWhisk
  private func analyze(documentId: String,  documentRev: String, onSuccess: (Result) -> Void, onFailure: () -> Void) {
    print("Triggering analysis of image...")
    
    
    let credentials = WhiskCredentials(accessKey: WhiskAppKey, accessToken: WhiskAppSecret)
    let whisk = Whisk(credentials: credentials)

    do {
      try whisk.invokeAction(name: ActionName, package: nil, namespace: ActionNamespace,
      parameters: [ "imageDocumentId" : documentId ], hasResult: true) { (reply, error) -> Void in

        self.deleteDocument(documentId, documentRev: documentRev)
      
        if let error = error {
          print("Error \(error)")
          onFailure()
        } else {
          let result = JSON(reply!)
          print("Analysis", result)
          onSuccess(Result(impl: result["result"]))
        }
      }
    } catch {
      print("Error during invoke \(error)")
      self.deleteDocument(documentId, documentRev: documentRev)
      onFailure()
    }
  }
  
  /// Step 4 - Delete the temporary image from Cloudant
  private func deleteDocument(documentId: String,  documentRev: String) {
    print("Removing temporary document...")
    
    Alamofire.request(.DELETE, "\(CloudantUrl)/\(CloudantDbName)/\(documentId)?rev=\(documentRev)", encoding: .JSON)
      .responseJSON { (response) -> Void in
        switch (response.result) {
        case .Success:
          print("Document deleted");
        case .Failure:
          print("Failed to delete document");
        }
    }
  }
  
}
