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

/// Controller for the Home page
class HomeController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  @IBOutlet weak var versionNumberLabel: UILabel!
  @IBOutlet weak var descriptionText: UITextView!
  
  var imageToProcess: UIImage!
  var imagePicker: UIImagePickerController!
  
  override func viewDidLoad() {
    descriptionText.textContainerInset = UIEdgeInsetsMake(15, 15, 15, 15)
    
    let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    versionNumberLabel.text = "v\(versionNumber) (\(buildNumber))"
  }

  /// Hides the navigation bar when the view is about to show
  override func viewWillAppear(_ animated: Bool) {
    navigationController?.setNavigationBarHidden(true, animated: animated)
  }
  
  /// Takes a photo with the Camera
  @IBAction func takePhoto(_ sender: UIButton) {
    imagePicker =  UIImagePickerController()
    imagePicker.allowsEditing = false
    imagePicker.delegate = self
    imagePicker.sourceType = .camera
    present(imagePicker, animated: true, completion: nil)
  }
  
  /// Selects a picture from the Photo Library
  @IBAction func selectPicture(_ sender: AnyObject) {
    imagePicker =  UIImagePickerController()
    imagePicker.allowsEditing = false
    imagePicker.delegate = self
    imagePicker.sourceType = .photoLibrary
    present(imagePicker, animated: true, completion: nil)
  }
  
  /// Called when an image has been selected, from the Camera or the Photo Library
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    print("Retrieving image...")
    imagePicker.dismiss(animated: true, completion: nil)
    imageToProcess = info[UIImagePickerControllerOriginalImage] as? UIImage
    
    // if this was a picture from the Camera, save it to the Camera Roll
    if(picker.sourceType == UIImagePickerControllerSourceType.camera) {
      UIImageWriteToSavedPhotosAlbum(imageToProcess, nil, nil, nil)
    }
    
    // move to the ResultController
    performSegue(withIdentifier: "Result", sender: nil)
  }

  /// Passes the selected image to the ResultController
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if (segue.identifier == "Result") {
      let controller = segue.destination as! ResultController
      controller.setImage(imageToProcess);
    }
  }

}
