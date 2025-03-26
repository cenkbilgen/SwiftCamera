//
//  CameraView.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import SwiftUI
import UIKit
import AVFoundation

public struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var model: CameraModel
    
    public init(model: CameraModel) {
        self.model = model
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        let layer = AVCaptureVideoPreviewLayer(session: model.session)
        layer.videoGravity = .resizeAspectFill
        view.previewLayer = layer
        view.layer.addSublayer(layer)
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
    
    class PreviewView: UIView {
        // subclassed UIView, this so that it can resize on layout more efficiently
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
