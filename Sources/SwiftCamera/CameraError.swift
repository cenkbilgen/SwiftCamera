//
//  CameraError.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import CoreVideo

public enum CameraError: Error {
    case captureFailure
    case noImageData
    case noVideoFrame
    case deviceSetupFailed
    case accessDenied
    case processingTimeOut
    case invalidInputDevice(String)
    case invalidOutputDevice(String)
    case outputDeviceNotConnected
    case bufferPoolSetupFailed(CVReturn)
}
