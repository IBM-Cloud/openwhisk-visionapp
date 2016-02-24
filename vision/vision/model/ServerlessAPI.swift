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

/**
 * Processes images with IBM Bluemix OpenWhisk
 */
class ServerlessAPI {
  
  // TODO: Change to your Cloudant credentials url
  let CLOUDANT_URL = "https://username:password@host.cloudant.com"
  let CLOUDANT_DB_NAME = "openwhisk-vision"
  
  // TODO: Change YOUR_NAMESPACE to the namespace where the vision-analysis action was created
  let OPENWHISK_ACTION_URL =  "https://openwhisk.ng.bluemix.net:443/api/v1/namespaces/YOUR_NAMESPACE/actions/vision-analysis?blocking=true"
  
  // TODO: Put your OpenWhisk authorization key here
  let OPENWHISK_AUTHORIZATION_KEY = ""
  
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
    Alamofire.request(.POST, CLOUDANT_URL + "/" + CLOUDANT_DB_NAME, parameters: [ "type": "temp-image" ], encoding: .JSON)
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
      "\(CLOUDANT_URL)/\(CLOUDANT_DB_NAME)/\(documentId)/image.jpg?rev=\(documentRev)",
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
    
    let basicAuthHeader = "Basic " +
      OPENWHISK_AUTHORIZATION_KEY.dataUsingEncoding(NSUTF8StringEncoding)!
        .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    
    Alamofire.request(.POST, OPENWHISK_ACTION_URL,
      headers: ["Authorization" : basicAuthHeader ],
      parameters: [ "imageDocumentId" : documentId ],
      encoding: .JSON)
      .responseJSON { (response) -> Void in
        // cleanup
        self.deleteDocument(documentId, documentRev: documentRev)
        
        switch (response.result) {
        case .Success:
          let result = JSON(data: response.data!)
          print("Analysis", result)
          onSuccess(Result(impl: result["response"]["result"]))
        case .Failure:
          onFailure()
        }
    }
  }
  
  /// Step 4 - Delete the temporary image from Cloudant
  private func deleteDocument(documentId: String,  documentRev: String) {
    print("Removing temporary document...")
    
    Alamofire.request(.DELETE, CLOUDANT_URL + "/" + CLOUDANT_DB_NAME + "/" + documentId + "?rev=" + documentRev, encoding: .JSON)
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
