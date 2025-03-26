//
//  CameraView.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import SwiftUI
import UIKit
import AVFoundation

public struct CameraLiveView: UIViewRepresentable {
    @ObservedObject var model: CameraModel
    
    public init(model: CameraModel) {
        self.model = model
    }
    
    public func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        let layer = AVCaptureVideoPreviewLayer(session: model.session)
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = CGColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 1)
        view.previewLayer = layer
        view.layer.addSublayer(layer)
        return view
    }
    
    public func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
    
    public class CameraPreviewUIView: UIView {
        // subclassed UIView, this so that it can resize on layout more efficiently
        var previewLayer: AVCaptureVideoPreviewLayer?
        public override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
