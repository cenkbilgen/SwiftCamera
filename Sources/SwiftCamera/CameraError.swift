//
//  CameraError.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

public enum CameraError: Error {
    case captureFailure
    case noImageData
    case deviceSetupFailed
    case accessDenied
    case processingTimeOut
    case invalidInputDevice(String)
    case invalidOutputDevice(String)
}
