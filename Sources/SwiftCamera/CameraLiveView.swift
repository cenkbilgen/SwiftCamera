//
//  CameraView.swift
//  CameraSample
//
//  Created by Cenk Bilgen on 2025-03-21.
//

import SwiftUI
import AVFoundation

#if os(macOS)
import AppKit
#elseif os(iOS) // includes iPadOS, TODO: not sure about VisionOS
import UIKit
#endif

#if os(macOS)
public struct CameraLiveView: NSViewRepresentable {
    @ObservedObject var model: CameraModel
    
    public init(model: CameraModel) {
        self.model = model
    }
    
    public func makeNSView(context: Context) -> CameraPreviewNSView {
        let layer = AVCaptureVideoPreviewLayer(session: model.session)
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        let view = CameraPreviewNSView(previewLayer: layer)
        return view
    }
    
    public func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}
    
    // subclassing, this so that it can resize on layout more efficiently
    public class CameraPreviewNSView: NSView {
        let previewLayer: AVCaptureVideoPreviewLayer
        
        required init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero) // will be set properly later
        }
        
        required init?(coder: NSCoder) {
            fatalError("Explicitly initialize \(#file).\(#function). You are using it wrong.")
        }
        
        public override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
        
        public override func makeBackingLayer() -> CALayer {
            previewLayer
        }
        
        public override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if let newWindow {
                previewLayer.frame = newWindow.frame
            }
        }
    }
}

#elseif os(iOS)  // iOS or iPadOS

public struct CameraLiveView: UIViewRepresentable {
    @ObservedObject var model: CameraModel
    @Environment(\.colorScheme) var scheme

    
    public init(model: CameraModel) {
        self.model = model
    }
    
    public func makeUIView(context: Context) -> CameraPreviewUIView {
        let layer = AVCaptureVideoPreviewLayer(session: model.session)
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor =  CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        let view = CameraPreviewUIView(previewLayer: layer)
        return view
    }
    
    public func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
    
    // subclassing, this so that it can resize on layout more efficiently
    public class CameraPreviewUIView: UIView {
        let previewLayer: AVCaptureVideoPreviewLayer
        
        required init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero) // will be set properly later
            layer.addSublayer(previewLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("Explicitly initialize \(#file).\(#function). You are using it wrong.")
        }
        
        public override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}

#endif
