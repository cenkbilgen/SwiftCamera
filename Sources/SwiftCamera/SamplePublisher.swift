//
//  SamplePublisher.swift
//  SwiftCamera
//
//  Created by cenk on 2025-04-03.
//

@preconcurrency import Combine

extension CameraModel {
    
    // NOTE: This function throws, but... if it doesn't throw the publisher it returns does not send any Failure, ie Failure == Never.

    // Basically, two possible failures, 1. Fail on streaming setup (ie no camera session or bad config), 2. Setup does not fail, but camera has errors while streaming (ie dropped frames).
    // We only catch the first kind, ignore the second.
    
    nonisolated public func startCaptureVideoStreamPublisher() throws -> AnyPublisher<CameraModel.SampleBuffer, Never> {
        let stream = try self.startCaptureVideoStream()

        return Deferred {
            let subject = PassthroughSubject<CameraModel.SampleBuffer, Never>()
            let task = Task(priority: .userInitiated) {
                do {
                    for await sample in stream {
                        if Task.isCancelled {
                            break
                        }
                        subject.send(sample)
                    }
                } catch {
                    
                }
                subject.send(completion: .finished)
            }

            return subject
                .handleEvents(receiveCancel: {
                    task.cancel()
                })
        }
        .eraseToAnyPublisher()
    }
    
}
