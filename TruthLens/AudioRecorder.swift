import AVFoundation

class AudioRecorder {
    private let engine = AVAudioEngine()
    var onChunk: ((Data) -> Void)?

    func start() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            var pcm16 = [Int16](repeating: 0, count: frameCount)
            for i in 0..<frameCount {
                pcm16[i] = Int16(channelData[i] * Float(Int16.max))
            }
            let data = Data(bytes: pcm16, count: pcm16.count * MemoryLayout<Int16>.size)
            self.onChunk?(data)
        }

        try? engine.start()
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}
