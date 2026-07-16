Pod::Spec.new do |s|
  s.name             = 'crosspromo_sdk'
  s.version          = '0.1.0'
  s.summary          = 'CrossPromo Flutter iOS bridge.'
  s.description      = 'Provides Apple App Transaction evidence to CrossPromo.'
  s.homepage         = 'https://github.com/Amian/crosspromo-sdk'
  s.license          = { :type => 'MIT' }
  s.author           = { 'CrossPromo' => 'sdk@crosspromo.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'
  s.frameworks       = 'StoreKit'
  s.resource_bundles = { 'CrossPromoPrivacy' => ['PrivacyInfo.xcprivacy'] }
end
