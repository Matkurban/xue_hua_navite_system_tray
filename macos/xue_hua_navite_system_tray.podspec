#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_navite_system_tray.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_navite_system_tray'
  s.version          = '1.0.0'
  s.summary          = 'A full-featured native desktop system tray plugin for Flutter across macOS, Windows, and Linux.'
  s.description      = <<-DESC
A production-grade Flutter desktop plugin providing native System Tray / Status Bar integration across macOS (NSStatusItem), Windows (Shell_NotifyIconW), and Linux (AppIndicator3 / GtkStatusIcon).
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_navite_system_tray'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => '3496354336@qq.com' }

  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_navite_system_tray/Sources/xue_hua_navite_system_tray/**/*'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
