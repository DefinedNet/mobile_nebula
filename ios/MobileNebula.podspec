Pod::Spec.new do |s|
  s.name         = 'MobileNebula'
  s.version      = '0.0.1'
  s.summary      = 'Go nebula library built with gomobile'
  s.homepage     = 'https://github.com/DefinedNet/mobile_nebula'
  s.author       = 'Defined Networking'
  s.source       = { :path => '.' }

  s.ios.deployment_target = '14.0'

  s.vendored_frameworks = 'MobileNebula.xcframework'

  s.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '"${PODS_XCFRAMEWORKS_BUILD_DIR}/MobileNebula"',
  }
  s.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '"${PODS_XCFRAMEWORKS_BUILD_DIR}/MobileNebula"',
  }

  s.script_phase = {
    :name => 'Build Go (gomobile)',
    :script => 'cd "$PODS_ROOT/../../" && ./gen-artifacts.sh ios',
    :execution_position => :before_compile,
    :always_out_of_date => '1',
  }
end
