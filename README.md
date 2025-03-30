### Usage

### CameraModel
1. Create a @StateObject instance of  `CameraModel`
2. Set the inputDevice of the camera model to the camera
3. Set the outputDevice, options are photo or video
4. call `start()` on the camera model

### CameraLiveView
1. A SwiftUI View showing input device live preview of the CameraModel you pass it

----
   
```swift
import SwiftCamera

// ...

@StateObject var camera = CameraModel()
@State var image: Image?

CameraLiveView(model: camera)
            .task {
                do {
                    try camera.setInputDevice(position: .back, type: .wide)
                    try camera.setOutputDevice(type: .photo)
                    camera.start()
                } catch {
                    print(error.localizedDescription)
                }
            }
            .onTapGesture {
                Task {
                    let photoData = try await camera.capturePhoto(type: .jpeg)
                    self.image = try await Image(importing: photoData,
                                                contentType: .jpeg)
                }
            }
            .overlay {
                image?
                    .resizable()
                    .scaleEffect(0.2)
                    .aspectRatio(contentMode: .fit)
            }

```
