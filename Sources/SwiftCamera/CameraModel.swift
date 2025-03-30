//
//  CameraModel.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import AVFoundation
import VideoToolbox

final public class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    private var pixelBufferPool: CVPixelBufferPool?
    private var dataContinuation: CheckedContinuation<Data, Error>?
    @preconcurrency private var sampleContinuation: AsyncStream<SampleBuffer>.Continuation?
    
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
    @Published public var currentPosition: CameraPosition?
    
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
        self.currentPosition = position
    }
    
    // TODO: just camera hard-coded for now
    public enum OutputType {
        case photo
        case video(fps: Double, resolution: AVCaptureSession.Preset)
        // case audio
    }
    @Published public var currentOutput: OutputType?

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
            self.currentOutput = .photo
            
        case .video(let fps, let resolution):
            session.sessionPreset = resolution
            let output = AVCaptureVideoDataOutput()
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
            self.currentOutput = .video(fps: fps, resolution: resolution)
            
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
    
    public var isRunning: Bool {
        session.isRunning
    }
    
    // MARK: Capture Photos
    
    public func capturePhoto(type: AVVideoCodecType? = .jpeg) async throws -> Data {
        guard let photoOutput else {
            throw CameraError.notCurrentCaptureOutputDevice
        }
        return try await withCheckedThrowingContinuation { [photoOutput] continuation in
            self.dataContinuation = continuation
            let format: [String: Any] = [
                AVVideoCodecKey: type
            ]
            let settings = AVCapturePhotoSettings(format: format)
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
        dataContinuation?.resume(returning: data)
        dataContinuation = nil
    }
    
    // MARK: Capture Video
    
    let queue = DispatchQueue(label: "VideoSampeBufferQueue.SwiftCamera")
    
    public struct SampleBuffer: @unchecked Sendable {
        public let imageBuffer: CVPixelBuffer
        public let timestamp: CMTime
        
        init(buffer: CMSampleBuffer) throws {
            try buffer.makeDataReady()
            guard let imageBuffer = buffer.imageBuffer else {
                throw AVError(.contentIsUnavailable)
            }
            self.imageBuffer = imageBuffer
            self.timestamp = buffer.presentationTimeStamp
        }
    }

    
    public func startCaptureVideoStream() async throws -> AsyncStream<SampleBuffer> {
        guard let videoOutput else {
            throw CameraError.notCurrentCaptureOutputDevice
        }
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        let (stream, continuation) = AsyncStream<SampleBuffer>.makeStream(bufferingPolicy: .bufferingOldest(1))
        self.sampleContinuation = continuation
        await MainActor.run {
            self.isCapturingVideo = true
        }
        return stream
    }
    
    public func stopCaptureVideoStream() async {
        self.sampleContinuation?.finish()
        videoOutput?.setSampleBufferDelegate(nil, queue: queue)
        await MainActor.run {
            self.isCapturingVideo = false
        }
    }
    
    @Published public var isCapturingVideo = false
    
    nonisolated private func handle(buffer: CMSampleBuffer) {
        guard let sampleContinuation else {
            return
        }
        do {
            let safeBuffer = try SampleBuffer(buffer: buffer)
            sampleContinuation.yield(safeBuffer)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        handle(buffer: sampleBuffer)
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropping samples")
    }

//    func setupPixelBufferPool(prototypeBuffer buffer: CVImageBuffer, pool: UnsafeMutablePointer<CVPixelBufferPool?>) throws {
//        let width = CVPixelBufferGetWidth(buffer)
//        let height = CVPixelBufferGetHeight(buffer)
//        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
//        
//        let poolAttributes: [String: Any] = [
//            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
//        ]
//        
//        let pixelBufferAttributes: [String: Any] = [
//            kCVPixelBufferWidthKey as String: width,
//            kCVPixelBufferHeightKey as String: height,
//            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
//            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
//        ]
//        
//        let rc = CVPixelBufferPoolCreate(
//            kCFAllocatorDefault,
//            poolAttributes as CFDictionary,
//            pixelBufferAttributes as CFDictionary,
//            pool
//        )
//        
//        guard rc == kCVReturnSuccess else {
//            throw CameraError.bufferPoolSetupFailed(rc)
//        }
//    }
    
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
