import AVFoundation
import Foundation

/// 効果音。音の素材を持たず、短い音を端末の中で作って鳴らす。
/// 消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）。
@MainActor
final class SoundBoard {
    enum Cue: CaseIterable {
        case tap, shot, defeat, combo, clear, breach, wave
    }

    var isEnabled = true
    private var players: [String: AVAudioPlayer] = [:]
    private var configured = false

    func play(_ cue: Cue, combo: Int = 1) {
        guard isEnabled else { return }
        configureSession()
        let key = "\(cue)-\(min(combo, 6))"
        if players[key] == nil {
            let data = Self.render(cue, combo: combo)
            if let player = try? AVAudioPlayer(data: data) {
                player.volume = Self.volume(cue)
                player.prepareToPlay()
                players[key] = player
            }
        }
        guard let player = players[key] else { return }
        player.currentTime = 0
        player.play()
    }

    private func configureSession() {
        guard !configured else { return }
        configured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    /// 音量の段階（五十音マインスイーパーの tap 0.4〜正解 0.8 にならう）
    static func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap: return 0.35
        case .shot: return 0.5
        case .defeat, .combo: return 0.6
        case .wave: return 0.5
        case .breach: return 0.55
        case .clear: return 0.7
        }
    }

    /// 音の並び（周波数・長さ秒）
    static func notes(_ cue: Cue, combo: Int) -> [(Double, Double)] {
        switch cue {
        case .tap: return [(1320, 0.03)]
        case .shot: return [(880, 0.05), (740, 0.06)]
        case .defeat: return [(659, 0.07), (988, 0.14)]
        case .combo:
            let step = pow(2.0, Double(min(combo, 6) * 2) / 12)
            return [(659 * step, 0.06), (988 * step, 0.14)]
        case .clear: return [(523, 0.09), (659, 0.09), (784, 0.09), (1047, 0.28)]
        case .breach: return [(147, 0.12), (110, 0.22)]
        case .wave: return [(784, 0.1), (988, 0.18)]
        }
    }

    /// 16bit・モノラルの WAV を作る
    static func render(_ cue: Cue, combo: Int) -> Data {
        let rate = 44_100.0
        var samples: [Int16] = []
        for (frequency, length) in notes(cue, combo: combo) {
            let count = Int(rate * length)
            for i in 0..<count {
                let t = Double(i) / rate
                let attack = min(1, t / 0.005)
                let release = exp(-4.5 * t / length)
                let tone = sin(2 * .pi * frequency * t) * 0.8 + sin(4 * .pi * frequency * t) * 0.15
                samples.append(Int16(max(-1, min(1, tone * attack * release)) * 26_000))
            }
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(44_100)); append(UInt32(88_200)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        for sample in samples { append(sample) }
        return data
    }
}
