//
//  CameraModel.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import AVFoundation
import VideoToolbox
import Observation

public struct CameraSample: @unchecked Sendable {
    public let buffer: CVPixelBuffer // not Sendable, must manually handle potential race condition
    public let timeStamp: CMTime
}

final public class CameraModel: NSObject, ObservableObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    private var pixelBufferPool: CVPixelBufferPool?
    private var dataContinuation: CheckedContinuation<Data, Error>?
    
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
    public enum OutputType {
        case photo
        case video(fps: Double, resolution: AVCaptureSession.Preset)
        // case audio
    }

    public func setOutputDevice(type: OutputType) throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        switch type {
        case .photo:
            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                throw CameraError.invalidOutputDevice(output.debugDescription)
            }
            self.videoOutput = nil
            self.photoOutput = output
            session.addOutput(output)
            
        case .video(let fps, let resolution):
            session.sessionPreset = resolution
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            output.alwaysDiscardsLateVideoFrames = true
            if let device = session.inputs.first as? AVCaptureDeviceInput {
                try device.device.lockForConfiguration()
                device.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                device.device.unlockForConfiguration()
            }
            guard session.canAddOutput(output) else {
                throw CameraError.invalidOutputDevice(videoOutput.debugDescription)
            }
            self.photoOutput = nil
            self.videoOutput = output
            session.addOutput(output)
            
//        case .audio:
//            let audioOutput = AVCaptureAudioDataOutput()
//            guard session.canAddOutput(audioOutput) else {
//                throw CameraError.invalidOutputDevice(audioOutput.debugDescription)
//            }
//            session.addOutput(audioOutput)
        }
    }
    
    // MARK: Start and Stop
    
    public func start() {
        queue.async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    // MARK: Capture Photos
    
    public func capturePhoto() async throws -> Data {
        guard let photoOutput else {
            throw CameraError.notCurrentCaptureOutputDevice
        }
        return try await withCheckedThrowingContinuation { [photoOutput] continuation in
            self.dataContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            dataContinuation?.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            dataContinuation?.resume(throwing: CameraError.noImageData)
            return
        }
//        let cameraSample = CameraSample(buffer: pixelBuffer, timeStamp: photo.timestamp)
        dataContinuation?.resume(returning: data)
        dataContinuation = nil
    }
    
    // MARK: Capture Video
    
    let queue = DispatchQueue(label: "VideoSampeBufferQueue.SwiftCamera")
    
    public func startCaptureVideo() async throws -> Data {
        guard let videoOutput else {
            throw CameraError.notCurrentCaptureOutputDevice
        }
        return try await withCheckedThrowingContinuation { [videoOutput] continuation in
            self.dataContinuation = continuation
            videoOutput.setSampleBufferDelegate(self, queue: queue)
        }
    }
    
    public func stopCaptureVideo() {
        videoOutput?.setSampleBufferDelegate(nil, queue: queue)
        self.dataContinuation = nil
    }
    
    public var isCapturingVideo: Bool {
        videoOutput?.sampleBufferDelegate != nil
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        do {
            guard let pixelBuffer = sampleBuffer.imageBuffer else {
                throw CameraError.noVideoFrame
            }
            if pixelBufferPool == nil {
                try setupPixelBufferPool(prototypeBuffer: pixelBuffer, pool: &pixelBufferPool)
            }
            var pixelBufferCopy: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &pixelBufferCopy)
            guard let pixelBufferCopy else {
                throw CameraError.noVideoFrame
            }
            
           // OSMemoryBarrier()
            // Copy content from the original buffer to the new one
//            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//            CVPixelBufferLockBaseAddress(pixelBufferCopy, [])
            
            // Perform the copy
//            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//            let height = CVPixelBufferGetHeight(pixelBuffer)
//            
//            if let srcAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
//               let destAddress = CVPixelBufferGetBaseAddress(pixelBufferCopy) {
//                memcpy(destAddress, srcAddress, bytesPerRow * height)
//            }
//            
////            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, [])
////            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//            
//            let cameraSample = CameraSample(buffer: pixelBufferCopy, timeStamp: sampleBuffer.presentationTimeStamp)
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            var image: CGImage?
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
            // TODO: Conver to Data
            dataContinuation?.resume(returning: Data())
        } catch {
            dataContinuation?.resume(throwing: CameraError.noVideoFrame)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropping samples")
    }

    func setupPixelBufferPool(prototypeBuffer buffer: CVImageBuffer, pool: UnsafeMutablePointer<CVPixelBufferPool?>) throws {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
        
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let rc = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            pool
        )
        
        guard rc == kCVReturnSuccess else {
            throw CameraError.bufferPoolSetupFailed(rc)
        }
    }
    
}

enum ImageTool {
    
    enum Error: Swift.Error {
        case conversionFailed
    }
    
    static func cgImage(from buffer: CVPixelBuffer) throws -> CGImage {
       var cgImage: CGImage?
       VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
       guard let cgImage else {
         throw Error.conversionFailed
       }
       return cgImage
     }
}
