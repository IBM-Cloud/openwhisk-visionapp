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
import SwiftyJSON
import RDHCollectionViewGridLayout

private let reuseIdentifier = "FaceCell"

/// Shows faces
class FacesController: UICollectionViewController {
  
  fileprivate var faces: [JSON]?
  fileprivate var image: UIImage?
  fileprivate var fakeFacesEnabled: Bool = false
  
  override func viewDidLoad() {
    let rdhLayout = self.collectionViewLayout as? RDHCollectionViewGridLayout
    rdhLayout?.lineSpacing = 5;
    rdhLayout?.itemSpacing = 5;
    rdhLayout?.lineItemCount = 1;
    rdhLayout?.scrollDirection = .horizontal
    rdhLayout?.lineSize = 96;
  }
  
  /// Shows random data while processing an image
  func setFakeFaces(_ enabled : Bool) {
    fakeFacesEnabled = enabled
    self.collectionView?.reloadData()
  }
  
  func setFaces(_ faces: [JSON], image: UIImage) {
    self.faces = faces
    self.image = image
    
    self.fakeFacesEnabled = false
    self.collectionView?.reloadData()
  }
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if (fakeFacesEnabled) {
      return 5
    } else {
      return faces == nil ? 0 : faces!.count
    }
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FaceCellRenderer
    if (fakeFacesEnabled) {
      cell.faceName.isHidden = true
      cell.faceAge.isHidden = true
    } else {
      // Configure the cell
      let face = faces![indexPath.row]
      
      // capture the face from the larger image
      let fromRect = CGRect(x: face["face_location"]["left"].intValue,
                            y: face["face_location"]["top"].intValue,
                            width: face["face_location"]["width"].intValue,
                            height: face["face_location"]["height"].intValue)
      let imageRef = (image!.cgImage)?.cropping(to: fromRect)
      cell.faceView.image = UIImage(cgImage: imageRef!, scale: UIScreen.main.scale, orientation: image!.imageOrientation)
      
      if (face["identity"].exists()) {
        cell.faceName.isHidden = false
        cell.faceName.text = face["identity"]["name"].string!
      } else {
        cell.faceName.isHidden = true
      }
      cell.faceAge.isHidden = false
      cell.faceAge.text = face["age"]["min"].stringValue + "-" + face["age"]["max"].stringValue
    }
    
    return cell
  }
  
}
