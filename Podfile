source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '10.0'
use_frameworks!

workspace 'vision.xcworkspace'
xcodeproj 'vision/vision.xcodeproj'

target 'vision' do
  pod 'OpenWhisk', :git => 'https://github.com/openwhisk/openwhisk-client-swift.git', :tag => '0.2.1'
  pod 'Alamofire', '4.0'
  pod 'AlamofireImage', '3.0'
  pod 'SwiftyJSON', '3.0'
  pod 'TagListView', :git => 'https://github.com/xhacker/TagListView', :branch => 'master'
  pod 'JGProgressHUD', '1.3.1'
  pod 'RDHCollectionViewGridLayout', '1.2.2'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
