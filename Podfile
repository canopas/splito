# Uncomment the next line to define a global platform for your project
platform :ios, '16'

workspace 'Splito.xcworkspace'
project 'Splito.xcodeproj'

use_frameworks!

def data_pods
  pod 'Swinject'
  pod 'SwiftLint'
  pod 'FirebaseCore'
  pod 'FirebaseAuth'
  pod 'GoogleSignIn'
  pod 'FirebaseFirestore'
  
  pod 'SSZipArchive'
  pod 'CocoaLumberjack/Swift'
end

def base_style_pods
  pod 'SwiftLint'
  pod 'CocoaLumberjack/Swift'
end

def splito_pods
  data_pods
  base_style_pods
end

target 'Data' do
  project 'Data/Data'
    data_pods
  
  target 'DataTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'BaseStyle' do
  project 'BaseStyle/BaseStyle'
    base_style_pods
    
  target 'BaseStyleTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'Splito' do
  
  splito_pods
  
  target 'SplitoTests' do
    inherit! :search_paths
    # Pods for testing
  end
  
  target 'SplitoUITests' do
    # Pods for testing
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end
