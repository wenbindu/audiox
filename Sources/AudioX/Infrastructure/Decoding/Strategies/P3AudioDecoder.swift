import Foundation

struct P3AudioDecoder: AudioDecoderStrategy {
    var id: String { "P3 Opus Stream" }

    var preferredFormats: Set<AudioFormat> {
        [.p3]
    }

    private var ffmpegPath: String? {
        ProcessRunner.executablePath(for: "ffmpeg")
    }

    func canDecode(_ track: AudioTrack) async -> Bool {
        track.format == .p3 && ffmpegPath != nil
    }

    func decode(_ track: AudioTrack) async throws -> DecodedMedia {
        guard let exe = ffmpegPath else {
            throw PlayerError.missingDependency("ffmpeg")
        }

        let packets = try P3PacketReader.readAudioPackets(from: track.url)
        guard !packets.isEmpty else {
            throw PlayerError.decodeFailed("P3 文件中没有可解码的 Opus 帧")
        }

        let baseName = "audiox-p3-\(UUID().uuidString)"
        let oggURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName).opus")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName).wav")

        do {
            let oggData = try OggOpusMuxer(sampleRate: 16_000, channels: 1)
                .mux(opusPackets: packets)
            try oggData.write(to: oggURL, options: .atomic)

            let args = [
                "-y",
                "-v", "error",
                "-i", oggURL.path,
                "-ac", "1",
                "-ar", "16000",
                "-c:a", "pcm_s16le",
                outputURL.path
            ]

            let result = try await ProcessRunner.run(executable: exe, arguments: args)
            try? FileManager.default.removeItem(at: oggURL)

            guard result.exitCode == 0 else {
                throw PlayerError.decodeFailed("P3/Opus 转码失败：\(result.error)")
            }

            return DecodedMedia(
                source: outputURL,
                removeAfterUse: true,
                usedBy: id
            )
        } catch {
            try? FileManager.default.removeItem(at: oggURL)
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }
}

private enum P3PacketReader {
    static func readAudioPackets(from url: URL) throws -> [Data] {
        let data = try Data(contentsOf: url)
        var offset = 0
        var packets: [Data] = []

        while offset + 4 <= data.count {
            let type = data[offset]
            let payloadSize = (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
            offset += 4

            guard payloadSize > 0 else {
                continue
            }

            guard offset + payloadSize <= data.count else {
                throw PlayerError.decodeFailed("P3 帧长度越界")
            }

            let payload = data.subdata(in: offset..<(offset + payloadSize))
            offset += payloadSize

            if type == 0 || type == 1 {
                packets.append(payload)
            }
        }

        if offset != data.count {
            throw PlayerError.decodeFailed("P3 文件尾部存在不完整帧")
        }

        return packets
    }
}

private struct OggOpusMuxer {
    let sampleRate: UInt32
    let channels: UInt8

    private let frameSamples: UInt64 = 2_880

    func mux(opusPackets: [Data]) throws -> Data {
        guard !opusPackets.isEmpty else {
            return Data()
        }

        var data = Data()
        var sequence: UInt32 = 0
        let serial = UInt32.random(in: 1...UInt32.max)

        data.append(try page(
            packet: opusHeadPacket(),
            headerType: 0x02,
            granulePosition: 0,
            serial: serial,
            sequence: sequence
        ))
        sequence += 1

        data.append(try page(
            packet: opusTagsPacket(),
            headerType: 0x00,
            granulePosition: 0,
            serial: serial,
            sequence: sequence
        ))
        sequence += 1

        var granulePosition: UInt64 = 0
        for (index, packet) in opusPackets.enumerated() {
            granulePosition += frameSamples
            let isLast = index == opusPackets.count - 1
            data.append(try page(
                packet: packet,
                headerType: isLast ? 0x04 : 0x00,
                granulePosition: granulePosition,
                serial: serial,
                sequence: sequence
            ))
            sequence += 1
        }

        return data
    }

    private func opusHeadPacket() -> Data {
        var packet = Data("OpusHead".utf8)
        packet.append(1)
        packet.append(channels)
        packet.appendLittleEndian(UInt16(0))
        packet.appendLittleEndian(sampleRate)
        packet.appendLittleEndian(UInt16(0))
        packet.append(0)
        return packet
    }

    private func opusTagsPacket() -> Data {
        let vendor = Data("AudioX".utf8)
        var packet = Data("OpusTags".utf8)
        packet.appendLittleEndian(UInt32(vendor.count))
        packet.append(vendor)
        packet.appendLittleEndian(UInt32(0))
        return packet
    }

    private func page(
        packet: Data,
        headerType: UInt8,
        granulePosition: UInt64,
        serial: UInt32,
        sequence: UInt32
    ) throws -> Data {
        let segments = try lacingSegments(for: packet.count)

        var page = Data("OggS".utf8)
        page.append(0)
        page.append(headerType)
        page.appendLittleEndian(granulePosition)
        page.appendLittleEndian(serial)
        page.appendLittleEndian(sequence)
        page.appendLittleEndian(UInt32(0))
        page.append(UInt8(segments.count))
        page.append(contentsOf: segments)
        page.append(packet)

        let checksum = OggCRC32.checksum(page)
        page.replaceSubrange(22..<26, with: Data(littleEndian: checksum))
        return page
    }

    private func lacingSegments(for packetSize: Int) throws -> [UInt8] {
        guard packetSize <= 65_025 else {
            throw PlayerError.decodeFailed("Opus 单帧过大，无法写入单个 Ogg page")
        }

        var remaining = packetSize
        var segments: [UInt8] = []
        while remaining >= 255 {
            segments.append(255)
            remaining -= 255
        }
        segments.append(UInt8(remaining))
        return segments
    }
}

private enum OggCRC32 {
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value) << 24
        for _ in 0..<8 {
            if (crc & 0x8000_0000) != 0 {
                crc = (crc << 1) ^ 0x04C1_1DB7
            } else {
                crc <<= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0
        for byte in data {
            let index = Int(((crc >> 24) ^ UInt32(byte)) & 0xff)
            crc = (crc << 8) ^ table[index]
        }
        return crc
    }
}

private extension Data {
    init<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndian = value.littleEndian
        self = Swift.withUnsafeBytes(of: &littleEndian) { Data($0) }
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        append(Data(littleEndian: value))
    }
}
