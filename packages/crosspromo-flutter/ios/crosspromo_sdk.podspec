Pod::Spec.new do |s|
  s.name             = 'crosspromo_sdk'
  s.version          = '0.1.0'
  s.summary          = 'CrossPromo Flutter integrity bridge.'
  s.description      = 'Provides App Attest and AppTransaction evidence to CrossPromo.'
  s.homepage         = 'https://github.com/Amian/crosspromo-sdk'
  s.license          = { :type => 'MIT' }
  s.author           = { 'CrossPromo' => 'sdk@crosspromo.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'
  s.frameworks       = 'DeviceCheck', 'StoreKit'
end
