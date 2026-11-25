//
//  CGImage+Encoded.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension CGImage {
    func encodedData(as type: UTType = .heic, compressionQuality: CGFloat = 0.85) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0) else {
            return nil
        }
        
        guard let destination = CGImageDestinationCreateWithData(mutableData, type.identifier as CFString, 1, nil) else {
            return nil
        }
        
        let addImageOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        
        CGImageDestinationAddImage(destination, self, addImageOptions as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
}
