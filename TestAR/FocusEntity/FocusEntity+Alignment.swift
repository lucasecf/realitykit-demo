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

extension FocusRectangle {
    // MARK: Helper Methods

    /// Update the position of the focus square.
    func updatePosition() {
        // We always keep the last 10 positions to use an average of them
        recentFocusEntityPositions = Array(recentFocusEntityPositions.suffix(10))

        // Move to average of recent positions to avoid jitter.
        let sum = recentFocusEntityPositions.reduce(SIMD3<Float>.zero, { $0 + $1 })
        let average = sum / Float(recentFocusEntityPositions.count)
        self.position = average
    }

    /// Update the transform of the focus square to be aligned with the camera.
    func updateTransform(raycastResult: ARRaycastResult) {
        updatePosition()

        if state != .initializing {
            updateAlignment(for: raycastResult)
        }
    }

    /// - Parameters:
    /// - Returns: ARRaycastResult if an existing plane geometry or an estimated plane are found, otherwise nil.
    func smartRaycast() -> ARRaycastResult? {
        guard let camTransform = arView?.cameraTransform else {
            return nil
        }

        let camDirection = camTransform.matrix.columns.2
        let camPositionVector: SIMD3<Float> = camTransform.translation
        let camDirectionVector: SIMD3<Float> = -[camDirection.x, camDirection.y, camDirection.z]

        // Perform the hit test.

        let allowedRayCast: ARRaycastQuery.Target
        if #available(iOS 13.4, *), ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            allowedRayCast = .existingPlaneGeometry // only supported on devices with Lidar
        } else {
            allowedRayCast = .estimatedPlane
        }

        let rcQuery = ARRaycastQuery(origin: camPositionVector,
                                     direction: camDirectionVector,
                                     allowing: allowedRayCast,
                                     alignment: .any)
        let results = arView?.session.raycast(rcQuery) ?? []

        // 1. Check for a result on an existing plane using geometry.
        guard let existingPlaneUsingGeometryResult = results.first(where: { $0.target == .existingPlaneGeometry }) else {
            // 2. As a fallback, check for a result on estimated planes.
            return results.first { $0.target == .estimatedPlane }
        }
        return existingPlaneUsingGeometryResult
    }

    /// Uses interpolation between orientations to create a smooth `easeOut` orientation adjustment animation.
    func performAlignmentAnimation(to newOrientation: simd_quatf) {
        // Interpolate between current and target orientations.
        orientation = simd_slerp(orientation, newOrientation, 0.15)
        // This length creates a normalized vector (of length 1) with all 3 components being equal.
        isChangingAlignment = shouldContinueAlignAnimation(to: newOrientation)
    }

    private func shouldContinueAlignAnimation(to newOrientation: simd_quatf) -> Bool {
        let testVector = simd_float3(repeating: 1 / sqrtf(3))
        let point1 = orientation.act(testVector)
        let point2 = newOrientation.act(testVector)
        let vectorsDot = simd_dot(point1, point2)
        // Stop interpolating when the rotations are close enough to each other.
        return vectorsDot < 0.999
    }

    private func updateAlignment(for raycastResult: ARRaycastResult) {
        var targetAlignment = raycastResult.worldTransform.orientation

        // Determine new current alignment
        var newAlignment: ARPlaneAnchor.Alignment?
        if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor {
            newAlignment = planeAnchor.alignment

            // Catching case when looking at ceiling
            if targetAlignment.act([0.0, 1.0, 0.0]).y < -0.9 {
                targetAlignment *= simd_quatf(angle: .pi, axis: [0.0, 1.0, 0.0])
            }

        } else if raycastResult.targetAlignment == .horizontal {
            newAlignment = .horizontal
        } else if raycastResult.targetAlignment == .vertical {
            newAlignment = .vertical
        }

        // add to list of recent alignments
        if let alignment = newAlignment {
            recentFocusEntityAlignments.append(alignment)
        }
        // Average using several most recent alignments.
        recentFocusEntityAlignments = Array(recentFocusEntityAlignments.suffix(20))

        let alignCount = CGFloat(recentFocusEntityAlignments.count)
        let horizontalHistory = CGFloat(recentFocusEntityAlignments.filter { $0 == .horizontal }.count)
        let horizontalMajority = (horizontalHistory > (alignCount / 2.0))

        // Alignment is same as most of the history - time to change it
        guard (newAlignment == .horizontal && horizontalMajority) || (newAlignment == .vertical && !horizontalMajority) else {
            // Alignment is still different than most of the history - ignore it for now
            return
        }

        // Change the focus entity's alignment
        if newAlignment != self.currentAlignment {
            isChangingAlignment = true
            self.currentAlignment = newAlignment

            // Uses interpolation.
            // Needs to be called on every frame that the animation is desired, Not just the first frame.
            performAlignmentAnimation(to: targetAlignment)
        } else {
            orientation = targetAlignment
        }
    }
}
