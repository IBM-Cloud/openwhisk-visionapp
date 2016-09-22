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
import TagListView
import JGProgressHUD
import AlamofireImage

/// Triggers the processing of the selected image and displays the results
class ResultController: UIViewController, TagListViewDelegate {
  
  @IBOutlet weak var backgroundImageView: UIImageView!
  @IBOutlet weak var imageView: UIImageView!

  @IBOutlet weak var facesContainerHeight: NSLayoutConstraint!
  @IBOutlet weak var facesContainer: UIView!
  
  @IBOutlet weak var imageTags: TagListView!
  
  var imageToProcess: UIImage!
  var facesController: FacesController!
  var originalFacesContainerHeight: CGFloat!

  override func viewDidLoad() {
    originalFacesContainerHeight = facesContainerHeight.constant

    imageTags.delegate = self
    
    if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
      imageTags.textFont = UIFont.systemFont(ofSize: 40)
    } else {
      imageTags.textFont = UIFont.systemFont(ofSize: 20)
    }
    imageTags.alignment = .center
  }
  
  func setImage(_ imageToProcess: UIImage) {
    self.imageToProcess = imageToProcess
  }
  
  override func viewWillAppear(_ animated: Bool) {
    navigationController?.setNavigationBarHidden(false, animated: animated)
    imageView.image = imageToProcess
    backgroundImageView.image = BlurFilter().filter(imageToProcess)
    enableGhostContent();
  }
  
  override func viewDidAppear(_ animated: Bool) {
    processImage()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if (segue.identifier == "Faces") {
      facesController = segue.destination as! FacesController
    }
  }
  
  /// Processes the image
  fileprivate func processImage() {
    let progressHUD = JGProgressHUD(style: .dark)
    progressHUD?.indicatorView = JGProgressHUDPieIndicatorView(hudStyle: .dark)
    progressHUD?.show(in: view, animated: true)
    progressHUD?.textLabel.text = "Preparing..."
    
    ServerlessAPI().process(imageToProcess,
      onProgress: { (phase, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
        progressHUD?.textLabel.text = "Uploading..."
        if (bytesWritten != -1) {
          DispatchQueue.main.async {
            progressHUD?.setProgress(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite), animated: true)
            if (totalBytesWritten == totalBytesExpectedToWrite) {
              progressHUD?.indicatorView = JGProgressHUDIndeterminateIndicatorView(hudStyle: .dark)
              progressHUD?.textLabel.text = "Analyzing"
            } else {
              progressHUD?.textLabel.text = String(format: "Uploading... %d%%", totalBytesWritten * 100 / totalBytesExpectedToWrite)
            }
            print("Total bytes written: \(totalBytesWritten) / \(totalBytesExpectedToWrite)")
          }
        }
      },
      onSuccess: { (result) -> Void in
        DispatchQueue.main.async {
          progressHUD?.dismiss(animated: true)
          self.disableGhostContent()
          self.updateWithResult(result)
        }
      },
      onFailure: { () -> Void in
        DispatchQueue.main.async {
          progressHUD?.dismiss(animated: true)
          self.disableGhostContent()
        }
      }
    )
  }
  
  /// Fills the UI with random data while the image is being processed
  fileprivate func enableGhostContent() {
    facesController.setFakeFaces(true)
    imageTags.removeAllTags()
    let source = " . . . . . . . . . "
    let count = UInt32(source.characters.count)
    for _ in 1...30 {
      let randomSize = max(5, Int(arc4random_uniform(count)))
//TODO(fredL)      imageTags.addTag(source[source.startIndex...source.indstartIndex.advancedBy(randomSize)])
    }
  }
  
  /// Removes the random data before showing the actual result
  fileprivate func disableGhostContent() {
    facesController.setFakeFaces(false)
    imageTags.removeAllTags()
  }
  
  /// Updates the user interface with the analysis results
  fileprivate func updateWithResult(_ result: Result) {
    print("Refreshing UI with results...", result);
    
    // sort the faces from left to right
    let faces = result.faces().sorted { (face1, face2) -> Bool in
      return face1["face_location"]["left"].intValue < face2["face_location"]["left"].intValue
    }
    // add a tag for each identified identity
    for face in faces {
      if (face["identity"].exists()) {
        imageTags.addTag(face["identity"]["name"].string!).isSelected = true
      }
    }
    
    facesController.setFaces(faces, image: imageToProcess)

    // hide the faces view if no face found
    if (faces.count > 0) {
      facesContainer.isHidden = false
      facesContainerHeight.constant = originalFacesContainerHeight
    } else {
      facesContainer.isHidden = true
      facesContainerHeight.constant = 0
    }
    
    // add tags for every keyword and tag, highlighting the one with higher score
    for keyword in result.keywords() {
      let tagView = imageTags.addTag(keyword["class"].string!)
      if (keyword["score"].doubleValue > 0.90) {
        tagView.isSelected = true
      }
    }
  }
  
  func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
    tagView.isSelected = !tagView.isSelected
  }
  
  @IBAction func shareResult(_ sender: AnyObject) {
    var sharingItems = [AnyObject]()
    
    // add the image to the list of shared items
    sharingItems.append(imageToProcess)
    
    // then all selected tags, plus the suffix configurable from the Settings app for Vision
    var text = ""
    for tag in imageTags.selectedTags() {
      text += " #" + tag.currentTitle!.camelCasedString
    }
    text = text + " " + UserDefaults.standard.string(forKey: "share_suffix")!
    sharingItems.append(text as AnyObject)
    
    // show the iOS share screen
    let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities: nil)
    activityViewController.popoverPresentationController?.sourceView = sender as? UIButton
    self.present(activityViewController, animated: true, completion: nil)
  }
  
}
