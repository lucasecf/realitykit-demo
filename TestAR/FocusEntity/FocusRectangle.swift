//
//  FocusEntity.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/26/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import RealityKit
import ARKit
import Combine

/**
 An `Entity` which is used to provide uses with visual cues about the status of ARKit world tracking.
 */
final class FocusRectangle: Entity, HasAnchoring {
    weak var arView: ARView?
    private var updateCancellable: Cancellable?

    // MARK: - Types
    enum State: Equatable {
        case initializing
        case tracking(raycastResult: ARRaycastResult, camera: ARCamera?)
    }

    // MARK: - Properties

    /// The most recent position of the focus square based on the current state.
    var lastPosition: SIMD3<Float>? {
        switch state {
        case .initializing:                   return nil
        case .tracking(let raycastResult, _): return raycastResult.worldTransform.translation
        }
    }

    var state: State = .initializing {
        didSet {
            guard state != oldValue else { return }

            switch state {
            case .initializing:
                animatePlaneDetectStateChange(found: false)

            case let .tracking(raycastResult, camera):
                updatePlaneDetection(for: raycastResult)
            }
        }
    }

    static let scaleForClosedSquare: Float = 1.0
    static let scaleForOpenSquare: Float = 0.5

    /// Indicates if the square is currently changing its alignment.
    var isChangingAlignment = false

    /// A camera anchor used for placing the focus entity in front of the camera.
    let cameraAnchor: AnchorEntity

    /// The focus square's current alignment.
    var currentAlignment: ARPlaneAnchor.Alignment?

    /// The focus square's most recent positions.
    var recentFocusEntityPositions: [SIMD3<Float>] = []

    /// The focus square's most recent alignments.
    var recentFocusEntityAlignments: [ARPlaneAnchor.Alignment] = []

    /// The primary node that controls the position of other `FocusEntity` nodes.
    let positioningEntity = Entity()

    private let color = UIColor.yellow
    var isOpen = true
    let segments: Segments

    // MARK: - Initialization
    init(on arView: ARView) {
        self.arView = arView
        self.cameraAnchor = AnchorEntity(.camera)
        self.segments = Segments(color: color)

        super.init()

        self.name = "FocusEntity"
        self.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

        arView.scene.addAnchor(cameraAnchor)
        arView.scene.addAnchor(self)
        addChild(positioningEntity)
        anchoring = AnchoringComponent(.world(transform: Transform.identity.matrix))

        setAutoUpdate()

        segments.setup(for: .init(width: 0.5, height: 0.3), on: positioningEntity)
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    // MARK: - Appearance

    /// Hides the focus square.
    func hide() {
        self.isEnabled = false
        //runAction(.fadeOut(duration: 0.5), forKey: "hide")
    }

    private func setAutoUpdate() {
        updateCancellable?.cancel()
        updateCancellable = arView?.scene.subscribe(to: SceneEvents.Update.self, { [weak self] event in
            self?.updateFocusEntity(event: event)
        })
    }

    /// Places the focus entity in front of the camera instead of on a plane.
    private func displayInactiveState() {
        // Positions focusEntity on center of camera
        let newPosition = cameraAnchor.convert(position: [0.0, 0.0, -1.0], to: nil)
        recentFocusEntityPositions.append(newPosition)
        updatePosition()

        // Rotate focus entity to face the camera with a smooth animation.
        var newRotation = arView?.cameraTransform.rotation ?? simd_quatf()
        newRotation *= simd_quatf(angle: .pi / 2.0, axis: [1.0, 0.0, 0.0])
        performAlignmentAnimation(to: newRotation)
    }

    private func animatePlaneDetectStateChange(found: Bool) {
        if found {
            onPlaneAnimation()
        } else {
            offPlaneAnimation()
        }
    }
}

// Camera / Place state updates detection
extension FocusRectangle {
    // Event listener
    private func updateFocusEntity(event: SceneEvents.Update?) {
        // Perform hit testing only when ARKit tracking is in a good state.
        guard let camera = arView?.session.currentFrame?.camera,
              case .normal = camera.trackingState,
              let result = smartRaycast()
        else {
            // We should place the focus entity in front of the camera instead of on a plane.
            displayInactiveState()
            state = .initializing
            return
        }

        state = .tracking(raycastResult: result, camera: camera)
    }

    private func updatePlaneDetection(for raycastResult: ARRaycastResult) {
        let planeFound = (raycastResult.anchor is ARPlaneAnchor)
        animatePlaneDetectStateChange(found: planeFound)

        recentFocusEntityPositions.append(raycastResult.worldTransform.translation)
        updateTransform(raycastResult: raycastResult)
    }

    private func offPlaneAnimation() {
        guard !isOpen else {
            return
        }
        isOpen = true

        for segment in segments.all {
            segment.open()
        }
        positioningEntity.scale = .init(repeating: FocusRectangle.scaleForOpenSquare)
    }

    private func onPlaneAnimation() {
        guard isOpen else {
            return
        }
        isOpen = false

        // Close animation
        for segment in segments.all {
            segment.close()
        }
        positioningEntity.scale = .init(repeating: FocusRectangle.scaleForClosedSquare)
    }
}
