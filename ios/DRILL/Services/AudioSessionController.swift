import AVFoundation

/// One place that owns the audio session, shared by the speech cues and the
/// buzzer.
///
/// `.playback` rather than `.ambient` on purpose: the whole point of speaking
/// the steps is that he can put the phone down mid-drill, and a phone in a
/// pocket is very often on silent. `.duckOthers` keeps whatever music he is
/// playing running underneath, just quieter.
enum AudioSessionController {
    private static var configured = false

    static func activate() {
        let session = AVAudioSession.sharedInstance()
        if !configured {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            configured = true
        }
        try? session.setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
