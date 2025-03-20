Pod::Spec.new do |s|
    s.name             = 'Liblantern'
    s.version          = '0.0.1'
    s.summary          = 'Lantern radiance plugin.'
    s.description      = 'Lantern radiance plugin.'
    s.homepage         = 'https://lantern.io'
    s.license          = { :file => '../LICENSE' }
    s.author           = { 'Brave New Software' => 'admin@lantern.io' }

    s.source           = { :path => '.' }
    s.source_files = 'Classes/**/*'
    s.public_header_files = 'Classes/**/*.h'

    s.vendored_frameworks = 'Liblantern.xcframework'

    s.dependency 'Flutter'
    s.platform = :ios, '11.0'

    # Flutter.framework does not contain a i386 slice.
    s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
    s.swift_version = '5.0'
    end
    