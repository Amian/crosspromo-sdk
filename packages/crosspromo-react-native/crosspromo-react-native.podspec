require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = 'crosspromo-react-native'
  s.version      = package['version']
  s.summary      = package['description']
  s.homepage     = 'https://github.com/Amian/crosspromo-sdk'
  s.license      = package['license']
  s.author       = { 'CrossPromo' => 'sdk@crosspromo.app' }
  s.source       = { :path => '.' }
  s.source_files = 'ios/**/*.{h,m,mm,swift}'
  s.platform     = :ios, '16.0'
  s.swift_version = '5.9'
  s.frameworks   = 'StoreKit'
  s.resource_bundles = { 'CrossPromoPrivacy' => ['ios/PrivacyInfo.xcprivacy'] }
  s.dependency 'React-Core'
end
