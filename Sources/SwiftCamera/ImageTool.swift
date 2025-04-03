//
//  Untitled.swift
//  SwiftCamera
//
//  Created by cenk on 2025-03-31.
//

import ImageIO
import CoreImage
import VideoToolbox
import Photos
import SwiftUI

public enum ImageToolError: Error {
    // TODO: add localized descriptions
    case imageSourceCreationFailed
    case cgImageCreationFailed
    case drawingContextCreationFailed
    case transformationFailed
}

public enum ImageTool {
    
    public static func cgImage(buffer: CVPixelBuffer) throws -> CGImage {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
        guard let cgImage else {
            throw ImageToolError.cgImageCreationFailed
        }
        return cgImage
    }
    
    public typealias PhotoProperties = [String: Any]
    
    public static func cgImage(data: Data) throws -> (image: CGImage, properties: PhotoProperties) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageToolError.imageSourceCreationFailed
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageToolError.cgImageCreationFailed
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        return (image, properties ?? [:])
    }
    
    public static func orientation(properties: PhotoProperties) -> UInt32 {
        if let orientation = properties["Orientation"] as? UInt32 {
            orientation
        } else if let tiffDictionary = properties["{TIFF}"] as? [String: Any],
                  let orientation = tiffDictionary["Orientation"] as? UInt32 {
            orientation
        } else {
            UInt32(1) // if not found return up
        }
    }
    
    public static func transform(properties: PhotoProperties) -> CGAffineTransform {
        let orientationValue = orientation(properties: properties) as UInt32
        return switch orientationValue {
        case 1: // Up (normal)
                .identity
        case 2: // Horizontal flip
                .init(scaleX: -1, y: 1)
        case 3: // 180° rotation
                .init(rotationAngle: .pi)
        case 4: // Vertical flip
                .init(scaleX: 1, y: -1)
        case 5: // Horizontal flip + 90° CCW rotation
                .init(scaleX: -1, y: 1)
                .concatenating(.init(rotationAngle: .pi/2))
        case 6: // 90° CCW rotation
                .init(rotationAngle: .pi/2)
        case 7: // Horizontal flip + 270° CCW rotation (or flip + 90° CW)
                .init(scaleX: -1, y: 1)
                .concatenating(.init(rotationAngle: -.pi/2))
        case 8: // 270° CCW rotation (or 90° CW)
                .init(rotationAngle: -.pi/2)
        default:
                .identity
        }
    }
    
    public static func orientation(properties: PhotoProperties) -> SwiftUI.Image.Orientation {
        let propertyOrientation: UInt32 = orientation(properties: properties)
        return switch propertyOrientation {
        case 1: // Up (normal)
                .up
        case 2: // Horizontal flip (mirrored along y-axis)
                .upMirrored
        case 3: // 180° rotation
                .down
        case 4: // Vertical flip (mirrored along x-axis)
                .downMirrored
        case 7: // Horizontal flip + 90° CCW rotation
                .leftMirrored
        case 8: // 90° CCW rotation
                .left  // CORRECTED: was .leftMirrored
        case 5: // Horizontal flip + 270° CCW rotation
                .rightMirrored
        case 6: // 270° CCW rotation
                .right
        default:
                .up
        }
    }
}
