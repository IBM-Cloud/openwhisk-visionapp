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
import Foundation

/// Adds functions to String
extension String {
  
  /**
   * - returns: a camel-case version of the String
   */
  var camelCasedString: String {
    
    var result = ""
    var capitalizeNext = true
    
    for char in self.characters {
      if (char == " ") {
        capitalizeNext = true
        continue;
      }
      
      if (capitalizeNext) {
        result += String(char).uppercaseString
        capitalizeNext = false
      } else {
        result += String(char)
      }
    }
    
    return result
  }
}