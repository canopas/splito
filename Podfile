# Uncomment the next line to define a global platform for your project
platform :ios, '16.0'

target 'Splito' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Splito
	pod 'Swinject'
  pod 'SwiftLint'
	pod 'FirebaseCore'
	pod 'FirebaseFirestore'

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
