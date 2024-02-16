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
  pod 'FirebaseFirestore'
end

def ui_pods
  pod 'UIPilot'
  pod 'Swinject'
  pod 'SwiftLint'
end

def splito_pods
  ui_pods
  data_pods
end

target 'Data' do
  project 'Data/Data.project'
  # MARK: Builders Pod
  data_pods
  
  target 'DataTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'UI' do
  project 'UI/UI.project'
  # MARK: Builders Pod
  ui_pods
  data_pods
  
  target 'UITests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'Splito' do
  
  # MARK: - Tools + Builders
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
