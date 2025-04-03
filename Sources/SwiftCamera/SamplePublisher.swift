//
//  SamplePublisher.swift
//  SwiftCamera
//
//  Created by cenk on 2025-04-03.
//

@preconcurrency import Combine

extension CameraModel {
    
    public func startCaptureVideoStreamPublisher() throws -> AnyPublisher<CameraModel.SampleBuffer, Never> {
        let subject = PassthroughSubject<CameraModel.SampleBuffer, Never>()
        Task { [subject] in
            let stream = try self.startCaptureVideoStream()
            for await sample in stream {
                if Task.isCancelled {
                    break
                }
                subject.send(sample)
            }
            subject.send(completion: .finished)
        }
        return subject.eraseToAnyPublisher()
    }
}
