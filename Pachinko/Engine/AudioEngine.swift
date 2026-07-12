import AVFoundation
import Foundation

/// Synthesized audio engine — all sounds generated via AudioKit-free AVAudioEngine
final class AudioEngine {
    private let engine = AVAudioEngine()
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        do {
            // Start with a silent pattern to init the audio session
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            print("[AudioEngine] Failed to start: \(error)")
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
    }

    // MARK: - Sound Effects

    func playPinHit() {
        playTone(frequency: 1800 + Float.random(in: -200...200), duration: 0.04, volume: 0.15)
    }

    func playLaunch() {
        // Rising whoosh via frequency sweep
        let dur: Float = 0.25
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let frameCount = AVAudioFrameCount(dur * Float(sampleRate))

        let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.outputNode.outputFormat(forBus: 0),
            frameCapacity: frameCount
        )!
        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(frameCount)
            let freq = 300 + t * 900
            let amp = sin(t * .pi) * 0.25 * (1 - t)
            buffer.floatChannelData?.pointee[i] = sin(2 * .pi * freq * t / Float(sampleRate / Int(freq))) * amp
        }

        playBuffer(buffer)
    }

    func playScore(value: Int) {
        // Ascending pentatonic arpeggio
        let notes: [Float] = [523, 587, 659, 784, 880] // C D E G A
        let note = notes[value % notes.count]
        playTone(frequency: note, duration: 0.08, volume: 0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.playTone(frequency: note * 1.5, duration: 0.06, volume: 0.15)
        }
    }

    func playDrain() {
        // Descending minor triad
        playTone(frequency: 440, duration: 0.1, volume: 0.12)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.playTone(frequency: 349, duration: 0.1, volume: 0.12)
        }
    }

    func playFeverStart() {
        // Square-wave fanfare
        for i in 0..<8 {
            let delay = Double(i) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playTone(frequency: 660 + Float(i) * 30, duration: 0.06, volume: 0.25, wave: .square)
            }
        }
    }

    // MARK: - Internal

    private func playTone(frequency: Float, duration: Float, volume: Float, wave: WaveType = .sine) {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let frameCount = AVAudioFrameCount(duration * Float(sampleRate))

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.outputNode.outputFormat(forBus: 0),
            frameCapacity: frameCount
        ) else { return }

        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let env = exp(-t * 12) // Exponential decay
            let phase = 2 * .pi * frequency * t
            let sample: Float = switch wave {
            case .sine:   sin(phase)
            case .square: sin(phase) >= 0 ? 1 : -1
            }
            buffer.floatChannelData?.pointee[i] = sample * env * volume
        }

        playBuffer(buffer)
    }

    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
            DispatchQueue.main.async {
                self.engine.detach(player)
            }
        }
        player.play()
    }

    private enum WaveType { case sine, square }
}
