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
 * Processes images with IBM Cloud Functions
 */
class ServerlessAPI {
  
  // TODO: Change to your Cloudant credentials url
  let CloudantUrl = "https://username:password@host.cloudant.com"
  let CloudantDbName = "openwhisk-vision"
  
  let ActionNamespace = "_"
  let ActionName = "vision-analysis"
  
  // TODO: Put your Cloud Functions key and token here
  // You can obtain the values at https://console.bluemix.net/openwhisk/learn/ios-sdk
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
  func process(_ image: UIImage, onProgress: @escaping (_ phase: String, _ fractionCompleted: Double) -> Void, onSuccess: @escaping (Result) -> Void, onFailure: @escaping () -> Void) {
    createDocument(image, onProgress: onProgress, onSuccess: onSuccess, onFailure: onFailure)
  }
  
  /// Step 1 - Create a new document in Cloudant
  fileprivate func createDocument(_ image: UIImage, onProgress: @escaping (_ phase: String, _ fractionCompleted: Double) -> Void, onSuccess: @escaping (Result) -> Void, onFailure: @escaping () -> Void) {
    print("Creating temporary image document...")

    Alamofire.request("\(CloudantUrl)/\(CloudantDbName)",
                      method: .post,
                      parameters: [ "type": "temp-image" ],
                      encoding: JSONEncoding.default)
      .responseJSON { (response) -> Void in
        switch (response.result) {
        case .success:
          let result = JSON(data: response.data!)
          print("Document created", result)
          self.attachImage(result["id"].string!, documentRev: result["rev"].string!,
            image: image, onProgress: onProgress, onSuccess: onSuccess, onFailure: onFailure)
        case .failure:
          onFailure()
        }
    }
  }
  
  /// Step 2 - Attach the image to the document
  fileprivate func attachImage(_ documentId: String, documentRev: String, image: UIImage, onProgress: @escaping (_ phase: String, _ fractionCompleted: Double) -> Void, onSuccess: @escaping (Result) -> Void, onFailure: @escaping () -> Void) {
    print("Attaching image to document", documentId, documentRev)
    
    let imageData = UIImageJPEGRepresentation(image, 0.3)
    Alamofire.upload(imageData!,
                     to: "\(CloudantUrl)/\(CloudantDbName)/\(documentId)/image.jpg?rev=\(documentRev)",
      method: .put)
      .uploadProgress(closure: { (progress) in
        onProgress("Uploading...", progress.fractionCompleted)
      })
      .responseJSON { (response) -> Void in
        switch (response.result) {
        case .success:
          let result = JSON(data: response.data!)
          print("Image uploaded", result)
          self.analyze(result["id"].string!, documentRev: result["rev"].string!, onSuccess: onSuccess, onFailure: onFailure)
        case .failure:
          onFailure()
        }
    }
    
  }
  
  /// Step 3 - Analyze the image with OpenWhisk
  fileprivate func analyze(_ documentId: String,  documentRev: String, onSuccess: @escaping (Result) -> Void, onFailure: @escaping () -> Void) {
    print("Triggering analysis of image...")
    
    
    let credentials = WhiskCredentials(accessKey: WhiskAppKey, accessToken: WhiskAppSecret)
    let whisk = Whisk(credentials: credentials)

    do {
      try whisk.invokeAction(name: ActionName, package: nil, namespace: ActionNamespace,
                             parameters: ([ "imageDocumentId": documentId ] as AnyObject),
                             hasResult: true) { (reply, error) -> Void in

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
  fileprivate func deleteDocument(_ documentId: String,  documentRev: String) {
    print("Removing temporary document...")
    
    Alamofire.request(
      "\(CloudantUrl)/\(CloudantDbName)/\(documentId)?rev=\(documentRev)",
      method: .delete, encoding: JSONEncoding.default)
      .responseJSON { (response) -> Void in
        switch (response.result) {
        case .success:
          print("Document deleted");
        case .failure:
          print("Failed to delete document");
        }
    }
  }
  
}
