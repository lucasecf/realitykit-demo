//
//  ContentView.swift
//  TestAR
//
//  Created by Lucas Frota on 08.11.21.
//

import ARKit
import SwiftUI
import RealityKit

// TODO:
// 1 - Finish ewviewing code
// 2 - Example downloading .usdz from remote
// 3 - Example setting textures


struct ContentView : View {
    var body: some View {
        return ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        let view = ARView()

        //view.environment.lighting.intensityExponent = 2

        // Start AR session
        let session = view.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
            }
        }
        session.run(config)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = session
        coachingOverlay.goal = .horizontalPlane
        view.addSubview(coachingOverlay)

        // Handle ARSession events via delegate
        context.coordinator.view = view
        //session.delegate = context.coordinator

        // Handle taps
        view.addGestureRecognizer(
            UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap)
            )
        )

        return view
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var view: ARView? {
            didSet {
                guard let view = view else { return }
                self.focusEntity = FocusRectangle(on: view)
            }
        }
        var focusEntity: FocusRectangle?

        @objc func handleTap() {
            guard let view = self.view, let focusEntity = self.focusEntity else { return }

            // Create a new anchor to add content to
            let anchor = AnchorEntity(plane: .horizontal)
            view.scene.anchors.append(anchor)

            // Add entity
            // To load remotely: https://maxxfrazer.medium.com/getting-started-with-realitykit-models-2f8159749f4e
            let entity = try! Entity.loadModel(named: "iOS-suzanneMetal")
            entity.position = focusEntity.position
            entity.generateCollisionShapes(recursive: true)
            view.installGestures([.rotation, .translation], for: entity)

            // Face the camera
            let camera = view.session.currentFrame!.camera
            let angle = camera.eulerAngles.y
            entity.orientation = simd_quatf(angle: angle, axis: [0.0, 1.0, 0.0])

            anchor.addChild(entity)
        }
    }
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
