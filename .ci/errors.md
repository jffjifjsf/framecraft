# 最近一次编译错误

- run: 43881078933
- sha: 3f999929251d2e25b3d8a153f48b704f28255049
- 时间: 2026-11-16 14:00:56Z

## 编译器 error 行

```
FrameCraft/Core/CameraController.swift:339:52: error: type 'AVCaptureDevice.ExposureMode' has no case 'autoExposure', but it does have a case named 'ContinuousAutoExposure'; if 'autoExposure' worked before, a recent change to the underlying C enum may have affected how prefixes are stripped from its case names
```

## 日志末尾 150 行

```
Copy /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/arm64-apple-ios-simulator.abi.json /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft.abi.json (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -strip-unsigned-binaries -strip-deterministic -strip-tool /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -resolve-src-symlinks -rename /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft.abi.json /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/arm64-apple-ios-simulator.abi.json

SwiftMergeGeneratedHeaders /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/FrameCraft-Swift.h /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft-Swift.h /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft-Swift.h (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-swiftHeaderTool -arch arm64 /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft-Swift.h -arch x86_64 /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft-Swift.h -o /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/FrameCraft-Swift.h

Copy /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/x86_64-apple-ios-simulator.swiftmodule /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.swiftmodule (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -strip-unsigned-binaries -strip-deterministic -strip-tool /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -resolve-src-symlinks -rename /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.swiftmodule /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/x86_64-apple-ios-simulator.swiftmodule

Copy /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/x86_64-apple-ios-simulator.swiftdoc /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.swiftdoc (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -strip-unsigned-binaries -strip-deterministic -strip-tool /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -resolve-src-symlinks -rename /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.swiftdoc /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/x86_64-apple-ios-simulator.swiftdoc

Copy /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/x86_64-apple-ios-simulator.abi.json /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.abi.json (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -strip-unsigned-binaries -strip-deterministic -strip-tool /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -resolve-src-symlinks -rename /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.abi.json /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/x86_64-apple-ios-simulator.abi.json

Copy /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/Project/x86_64-apple-ios-simulator.swiftsourceinfo /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.swiftsourceinfo (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -strip-unsigned-binaries -strip-deterministic -strip-tool /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -resolve-src-symlinks -rename /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/x86_64/FrameCraft.swiftsourceinfo /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/Project/x86_64-apple-ios-simulator.swiftsourceinfo

Copy /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/Project/arm64-apple-ios-simulator.swiftsourceinfo /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft.swiftsourceinfo (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -strip-unsigned-binaries -strip-deterministic -strip-tool /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -resolve-src-symlinks -rename /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft.swiftsourceinfo /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.swiftmodule/Project/arm64-apple-ios-simulator.swiftsourceinfo

SwiftCompile normal x86_64 Compiling\ SpecView.swift,\ FilterStrip.swift,\ GeneratedAssetSymbols.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/SpecView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/FilterStrip.swift /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/GeneratedAssetSymbols.swift (in target 'FrameCraft' from project 'FrameCraft')
SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/SpecView.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/FilterStrip.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/GeneratedAssetSymbols.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal arm64 Compiling\ SpecView.swift,\ FilterStrip.swift,\ GeneratedAssetSymbols.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/SpecView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/FilterStrip.swift /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/GeneratedAssetSymbols.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/SpecView.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/FilterStrip.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/GeneratedAssetSymbols.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal arm64 Compiling\ FrameCraftApp.swift,\ Models.swift,\ FrameAnalyzer.swift,\ CameraController.swift /Users/runner/work/framecraft/framecraft/FrameCraft/App/FrameCraftApp.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/Models.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift (in target 'FrameCraft' from project 'FrameCraft')
SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/App/FrameCraftApp.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/Models.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    
/Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift:211:13: warning: variable 'totalSal' was never mutated; consider changing to 'let' constant
        var totalSal = integral[ah * W1 + aw]
        ~~~ ^
        let

SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    
/Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift:339:52: error: type 'AVCaptureDevice.ExposureMode' has no case 'autoExposure', but it does have a case named 'ContinuousAutoExposure'; if 'autoExposure' worked before, a recent change to the underlying C enum may have affected how prefixes are stripped from its case names
                   device.isExposureModeSupported(.autoExposure) {
                                                   ^

Failed frontend command:
/Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend -frontend -c -primary-file /Users/runner/work/framecraft/framecraft/FrameCraft/App/FrameCraftApp.swift -primary-file /Users/runner/work/framecraft/framecraft/FrameCraft/Core/Models.swift -primary-file /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift -primary-file /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/DemoScene.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FaceAnalyzer.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/ImageFilter.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/Support.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/CameraView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/ReviewView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/SpecView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/FilterStrip.swift /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/GeneratedAssetSymbols.swift -supplementary-output-file-map /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/supplementaryOutputs-2 -emit-localized-strings -emit-localized-strings-path /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64 -target arm64-apple-ios16.0-simulator -Xllvm -aarch64-use-tbi -enable-objc-interop -sdk /Applications/Xcode_16.4.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator18.5.sdk -I /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator -F /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator -no-color-diagnostics -enable-testing -g -debug-info-format\=dwarf -dwarf-version\=4 -module-cache-path /Users/runner/work/framecraft/framecraft/build/DerivedData/ModuleCache.noindex -swift-version 5 -enforce-exclusivity\=checked -Onone -D DEBUG -serialize-debugging-options -const-gather-protocols-file /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraft_const_extract_protocols.json -enable-experimental-feature DebugDescriptionMacro -enable-bare-slash-regex -empty-abi-descriptor -validate-clang-modules-once -clang-build-session-file /Users/runner/work/framecraft/framecraft/build/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -working-directory -Xcc /Users/runner/work/framecraft/framecraft -resource-dir /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /Users/runner/work/framecraft/framecraft -Xcc -ivfsstatcache -Xcc /Users/runner/work/framecraft/framecraft/build/DerivedData/SDKStatCaches.noindex/iphonesimulator18.5-22F76-96ae0914227b19deccb34b33ba7b5dea.sdkstatcache -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/swift-overrides.hmap -Xcc -iquote -Xcc /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/FrameCraft-generated-files.hmap -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/FrameCraft-own-target-headers.hmap -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/FrameCraft-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/FrameCraft-project-headers.hmap -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Products/Debug-iphonesimulator/include -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/DerivedSources -Xcc -DDEBUG\=1 -module-name FrameCraft -frontend-parseable-output -disable-clang-spi -target-sdk-version 18.5 -target-sdk-name iphonesimulator18.5 -external-plugin-path /Applications/Xcode_16.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/swift/host/plugins\#/Applications/Xcode_16.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/swift-plugin-server -external-plugin-path /Applications/Xcode_16.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/local/lib/swift/host/plugins\#/Applications/Xcode_16.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/swift-plugin-server -in-process-plugin-server-path /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins -plugin-path /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/lib/swift/host/plugins -o /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraftApp.o -o /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/Models.o -o /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameAnalyzer.o -o /Users/runner/work/framecraft/framecraft/build/DerivedData/Build/Intermediates.noindex/FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/CameraController.o -index-unit-output-path /FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameCraftApp.o -index-unit-output-path /FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/Models.o -index-unit-output-path /FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/FrameAnalyzer.o -index-unit-output-path /FrameCraft.build/Debug-iphonesimulator/FrameCraft.build/Objects-normal/arm64/CameraController.o -index-store-path /Users/runner/work/framecraft/framecraft/build/DerivedData/Index.noindex/DataStore -index-system-modules
SwiftDriverJobDiscovery normal arm64 Compiling SpecView.swift, FilterStrip.swift, GeneratedAssetSymbols.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftCompile normal x86_64 Compiling\ DemoScene.swift,\ FaceAnalyzer.swift,\ ImageFilter.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/DemoScene.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FaceAnalyzer.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/ImageFilter.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/DemoScene.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FaceAnalyzer.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    
/Users/runner/work/framecraft/framecraft/FrameCraft/Core/FaceAnalyzer.swift:96:45: warning: conditional downcast from '[VNFaceObservation]?' to '[VNFaceObservation]' does nothing
        guard let results = request.results as? [VNFaceObservation], !results.isEmpty else {
                            ~~~~~~~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~
                                           

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/ImageFilter.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftDriverJobDiscovery normal arm64 Compiling DemoScene.swift, FaceAnalyzer.swift, ImageFilter.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftCompile normal x86_64 Compiling\ FrameCraftApp.swift,\ Models.swift,\ FrameAnalyzer.swift,\ CameraController.swift /Users/runner/work/framecraft/framecraft/FrameCraft/App/FrameCraftApp.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/Models.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift (in target 'FrameCraft' from project 'FrameCraft')
SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/App/FrameCraftApp.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/Models.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftDriverJobDiscovery normal arm64 Compiling Support.swift, CameraView.swift, ReviewView.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftCompile normal x86_64 Compiling\ Support.swift,\ CameraView.swift,\ ReviewView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/Support.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/CameraView.swift /Users/runner/work/framecraft/framecraft/FrameCraft/UI/ReviewView.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/Support.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/CameraView.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftCompile normal x86_64 /Users/runner/work/framecraft/framecraft/FrameCraft/UI/ReviewView.swift (in target 'FrameCraft' from project 'FrameCraft')
    cd /Users/runner/work/framecraft/framecraft
    

SwiftDriverJobDiscovery normal x86_64 Compiling SpecView.swift, FilterStrip.swift, GeneratedAssetSymbols.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftDriverJobDiscovery normal x86_64 Compiling DemoScene.swift, FaceAnalyzer.swift, ImageFilter.swift (in target 'FrameCraft' from project 'FrameCraft')

SwiftDriverJobDiscovery normal x86_64 Compiling Support.swift, CameraView.swift, ReviewView.swift (in target 'FrameCraft' from project 'FrameCraft')

** BUILD FAILED **


The following build commands failed:
	SwiftCompile normal arm64 /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift (in target 'FrameCraft' from project 'FrameCraft')
	SwiftCompile normal arm64 Compiling\ FrameCraftApp.swift,\ Models.swift,\ FrameAnalyzer.swift,\ CameraController.swift /Users/runner/work/framecraft/framecraft/FrameCraft/App/FrameCraftApp.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/Models.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/FrameAnalyzer.swift /Users/runner/work/framecraft/framecraft/FrameCraft/Core/CameraController.swift (in target 'FrameCraft' from project 'FrameCraft')
	Building project FrameCraft with scheme FrameCraft and configuration Debug
(3 failures)
```
