//
//  CameraModel.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import AVFoundation
import Observation


@Observable
final public class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    
    private var preferredCameraDevice: AVCaptureDevice? {
        AVCaptureDevice.systemPreferredCamera
    }
    
    public enum CameraPosition {
        case front, back
        var captureDevicePosition: AVCaptureDevice.Position {
            switch self {
            case .front: .front
            case .back: .back
            }
        }
    }
    
    public enum CameraType {
        case wide, lidar, ultraWide
        var captureDeviceType: AVCaptureDevice.DeviceType {
            switch self {
            case .wide: .builtInWideAngleCamera
            case .lidar: .builtInLiDARDepthCamera
            case .ultraWide: .builtInUltraWideCamera
            }
        }
    }
    
    public func setInputDevice(position: CameraPosition, type: CameraType) throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        let device = AVCaptureDevice.default(type.captureDeviceType, for: .video, position: position.captureDevicePosition)
        guard let device else {
            print("Failed to create video input")
            throw CameraError.deviceSetupFailed
        }
        let videoInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(videoInput) else {
            throw CameraError.invalidInputDevice(videoInput.debugDescription)
        }
        session.addInput(videoInput)
    }
    
    // TODO: just camera hard-coded for now
    public func setOutputDevice() throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        let output = photoOutput // TODO
        guard session.canAddOutput(output) else {
            throw CameraError.invalidOutputDevice(output.debugDescription)
        }
        session.addOutput(output)
    }
    
    @MainActor public func start() {
        session.startRunning()
    }
    
    @MainActor public func stop() {
        session.stopRunning()
    }
    
    public func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            photoContinuation?.resume(throwing: error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            photoContinuation?.resume(throwing: CameraError.noImageData)
            return
        }
        photoContinuation?.resume(returning: imageData)
        photoContinuation = nil
    }
}

