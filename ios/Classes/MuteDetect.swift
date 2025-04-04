import Foundation
import AudioToolbox
import QuartzCore

public class MuteDetect: NSObject {

    public static let shared = MuteDetect()

    private var soundID: SystemSoundID = 0

    private static var muteSoundUrl: URL {
        // First try to find the resource in the main bundle
        if let url = Bundle.main.url(forResource: "mute", withExtension: "aiff") {
            return url
        }
        
        // Then try to find it in the plugin bundle
        if let url = Bundle(for: MuteDetect.self).url(forResource: "mute", withExtension: "aiff") {
            return url
        }
        
        // Then try to find it in the resource bundle with the custom name
        if let url = Bundle(for: MuteDetect.self).url(forResource: "ios_Assets_mute", withExtension: "aiff") {
            return url
        }
        
        // Finally, try to find it in the MoonNativeResources bundle
        let bundleUrl = Bundle(for: MuteDetect.self).url(forResource: "MoonNativeResources", withExtension: "bundle")
        if let resourceBundle = bundleUrl.flatMap({ Bundle(url: $0) }),
           let url = resourceBundle.url(forResource: "ios_Assets_mute", withExtension: "aiff") {
            return url
        }
        
        // If all else fails, provide a fallback that will cause a runtime error only if actually used
        // This allows the class to be compiled and instantiated even if the resource is missing
        fatalError("Unable to find mute sound file in any bundle. Please check the bundle configuration.")
    }

    private override init() {
        super.init()

        self.soundID = 1
        
        let result = AudioServicesCreateSystemSoundID(MuteDetect.muteSoundUrl as CFURL, &self.soundID)
        if result == kAudioServicesNoError {
            let weakSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

            AudioServicesAddSystemSoundCompletion(self.soundID, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue, { soundId, weakSelfPointer in
                guard let weakSelfPointer = weakSelfPointer else { return }
                let weakSelfValue = Unmanaged<MuteDetect>.fromOpaque(weakSelfPointer).takeUnretainedValue()
                guard let startTime = weakSelfValue.startTime else { return }
                let isMute = CACurrentMediaTime() - startTime < 0.1
                weakSelfValue.completions.forEach({ (completion) in
                    completion(isMute)
                })
                weakSelfValue.completions.removeAll()
                weakSelfValue.startTime = nil
            }, weakSelf)

            var yes: UInt32 = 1
            AudioServicesSetProperty(kAudioServicesPropertyIsUISound,
                                     UInt32(MemoryLayout.size(ofValue: self.soundID)),
                                     &self.soundID,
                                     UInt32(MemoryLayout.size(ofValue: yes)),
                                     &yes)
        } else {
            self.soundID = 0
        }
    }

    public typealias MuteDetectCompletion = ((Bool) -> ())

    private var completions: [MuteDetectCompletion] = []

    private var startTime: CFTimeInterval? = nil

    public func detectSound(_ completion: @escaping MuteDetectCompletion) {
        guard soundID != 0 else {
            completion(false)
            return
        }
        self.completions.append(completion)
        if self.startTime == nil {
            self.startTime = CACurrentMediaTime()
            AudioServicesPlaySystemSound(self.soundID)
        }
    }

    deinit {
        if self.soundID != 0 {
            AudioServicesRemoveSystemSoundCompletion(self.soundID)
            AudioServicesDisposeSystemSoundID(self.soundID)
        }
    }

}
