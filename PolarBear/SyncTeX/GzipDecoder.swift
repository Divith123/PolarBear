//
//  GzipDecoder.swift
//  PolarBear
//

import Compression
import Foundation

/// Reads `.gz` files (such as `main.synctex.gz`) using the Compression framework: the gzip
/// header is skipped and the deflate stream inside is inflated.
nonisolated enum GzipDecoder {
    enum DecodeError: Error {
        case notGzip
        case truncated
    }

    static func decode(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count > 18, bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 8 else { throw DecodeError.notGzip }

        let flags = bytes[3]
        var offset = 10
        if flags & 0x04 != 0 { // extra field
            guard offset + 2 <= bytes.count else { throw DecodeError.truncated }
            offset += 2 + Int(bytes[offset]) + Int(bytes[offset + 1]) << 8
        }
        if flags & 0x08 != 0 { offset = try skipString(in: bytes, from: offset) } // name
        if flags & 0x10 != 0 { offset = try skipString(in: bytes, from: offset) } // comment
        if flags & 0x02 != 0 { offset += 2 } // header checksum
        guard offset < bytes.count - 8 else { throw DecodeError.truncated }

        let deflate = Data(bytes[offset..<(bytes.count - 8)]) // the last 8 bytes are CRC32 and size
        return try (deflate as NSData).decompressed(using: .zlib) as Data
    }

    private static func skipString(in bytes: [UInt8], from start: Int) throws -> Int {
        var index = start
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        guard index < bytes.count else { throw DecodeError.truncated }
        return index + 1
    }
}
