//
//  AvatarPhoto.swift
//  PolarBear
//

import SwiftUI
import ImageIO
import os

/// Reads, shrinks and stores the profile photo. 256 pixels is plenty for a 96 pt avatar.
nonisolated enum AvatarPhoto {
    private static let maximumPixels = 256

    static var storageURL: URL {
        URL.applicationSupportDirectory.appending(path: "PolarBear/profile-photo.png")
    }

    /// A shrunken copy of the image at `url`, or `nil` if it is not an image.
    @concurrent
    static func load(from url: URL) async -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    static func stored() -> NSImage? {
        NSImage(contentsOf: storageURL)
    }

    static func store(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: storageURL, options: .atomic)
        } catch {
            Log.project.error("Could not save the profile photo: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func removeStored() {
        try? FileManager.default.removeItem(at: storageURL)
    }
}
