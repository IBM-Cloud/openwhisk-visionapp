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
import SwiftyJSON

/// Models the analysis result
class Result: CustomStringConvertible {
  
  let impl: JSON
  
  /**
   * - impl: the wrapped result object
   */
  init(impl: JSON) {
    self.impl = impl
  }
  
  /**
   * - returns: the tags found by Watson for the image or an empty array if no tag found
   */
  func tags() -> [JSON] {
    if (impl["visual_recognition"].isExists() && impl["visual_recognition"]["images"].isExists()) {
      return impl["visual_recognition"]["images"][0]["labels"].array!
    } else {
      return []
    }
  }
  
  /**
   * - returns: the keywords found by AlchemyAPI for the image or an empty array if no keyword found
   */
  func keywords() -> [JSON] {
    if (impl["image_keywords"].isExists() && impl["image_keywords"]["imageKeywords"].isExists()) {
      return impl["image_keywords"]["imageKeywords"].array!
    } else {
      return []
    }
  }
  
  /**
   * - returns: the faces found by AlchemyAPI for the image or an empty array if no face found
   */
  func faces() -> [JSON] {
    if (impl["face_detection"].isExists() && impl["face_detection"]["imageFaces"].isExists()) {
      return impl["face_detection"]["imageFaces"].array!
    } else {
      return []
    }
  }
  
  /// The JSON representation of this result
  var description: String {
    return self.impl.description
  }
  
}
