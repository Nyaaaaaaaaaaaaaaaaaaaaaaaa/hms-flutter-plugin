Pod::Spec.new do |s|
  s.name             = 'huawei_map'
  s.version          = '6.11.2.304'
  s.summary          = 'Huawei Map Kit plugin for Flutter with an iOS compatibility bridge.'
  s.description      = <<-DESC
Huawei Map Kit platform views and method-channel bindings for Flutter. The
official Huawei Map Kit iOS frameworks are integrated by the host application
and loaded by this pod at runtime; they are not redistributed by the plugin.
                       DESC
  s.homepage         = 'https://github.com/Nyaaaaaaaaaaaaaaaaaaaaaaaa/hms-flutter-plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Huawei Technologies Co., Ltd.' => 'https://www.huawei.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '11.0'
  s.frameworks       = 'CoreLocation', 'GLKit', 'UIKit'
  s.libraries        = 'c++', 'z', 'bz2'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
  s.swift_version = '5.0'
end
