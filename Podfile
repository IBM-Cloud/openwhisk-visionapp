source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '10.0'
use_frameworks!

workspace 'vision.xcworkspace'
project 'vision/vision.xcodeproj'

target 'vision' do
  pod 'OpenWhisk', :git => 'https://github.com/openwhisk/openwhisk-client-swift.git', :tag => '0.2.2'
  pod 'Alamofire', '4.2'
  pod 'AlamofireImage', '3.2'
  pod 'SwiftyJSON', '3.1.3'
  pod 'TagListView', '1.1.0'
  pod 'JGProgressHUD', '1.4'
  pod 'RDHCollectionViewGridLayout', '1.2.5'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
