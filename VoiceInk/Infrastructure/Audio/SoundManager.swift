import CoreAudio
import Foundation
import SwiftUI

@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private let playbackEngine = SoundPlaybackEngine()

    private init() {
        setupSounds()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadCustomSounds),
            name: NSNotification.Name("CustomSoundsChanged"),
            object: nil
        )
    }

    private func setupSounds() {
        let customSoundManager = CustomSoundManager.shared
        playbackEngine.setup(
            defaultStartURL: customSoundManager.builtInSoundURL(for: .start),
            defaultStopURL: customSoundManager.builtInSoundURL(for: .stop),
            defaultEscURL: CustomSoundManager.BuiltInSound.sound7.bundleURL,
            customStartURL: customSoundManager.getCustomSoundURL(for: .start),
            customStopURL: customSoundManager.getCustomSoundURL(for: .stop)
        )
    }

    @objc private func reloadCustomSounds() {
        setupSounds()
    }

    // Playing a cue on Bluetooth headphones makes AirPods hop over from the iPhone, cutting what is playing there
    private var isDefaultOutputBuiltIn: Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr
        else { return false }

        var transportType = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyTransportType
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType) == noErr else { return false }
        return transportType == kAudioDeviceTransportTypeBuiltIn
    }

    func playStartSound() {
        guard CustomSoundManager.shared.isSoundEnabled(for: .start), isDefaultOutputBuiltIn else { return }
        playbackEngine.playStartSound()
    }

    func playStopSound() {
        guard CustomSoundManager.shared.isSoundEnabled(for: .stop), isDefaultOutputBuiltIn else { return }
        playbackEngine.playStopSound()
    }

    func playEscSound() {
        guard CustomSoundManager.shared.hasAnyRecordingSoundEnabled, isDefaultOutputBuiltIn else { return }
        playbackEngine.playEscSound()
    }
}
