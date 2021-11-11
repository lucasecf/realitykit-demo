//
//  FocusEntity+Segment.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/28/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import UIKit
import RealityKit

extension FocusRectangle {
    /*
     The focus square consists of eight segments as follows, which can be individually animated.

         s1  s2
         _   _
     s3 |     | s4

     s5 |     | s6
         -   -
         s7  s8
     */
    struct Segments {
        let s1: Segment
        let s2: Segment
        let s3: Segment
        let s4: Segment
        let s5: Segment
        let s6: Segment
        let s7: Segment
        let s8: Segment

        var all: [Segment] {
            [s1, s2, s3, s4, s5, s6, s7, s8]
        }

        var topEdge: (begin: Segment, end: Segment) {
            (s1, s2)
        }
        var rightEdge: (begin: Segment, end: Segment) {
            (s4, s6)
        }
        var bottomEdge: (begin: Segment, end: Segment) {
            (s8, s7)
        }
        var leftEdge: (begin: Segment, end: Segment) {
            (s5, s3)
        }

        init(color: Material.Color) {
            self.s1 = Segment(name: "s1", corner: .topLeft, alignment: .horizontal, color: color)
            self.s2 = Segment(name: "s2", corner: .topRight, alignment: .horizontal, color: color)
            self.s3 = Segment(name: "s3", corner: .topLeft, alignment: .vertical, color: color)
            self.s4 = Segment(name: "s4", corner: .topRight, alignment: .vertical, color: color)
            self.s5 = Segment(name: "s5", corner: .bottomLeft, alignment: .vertical, color: color)
            self.s6 = Segment(name: "s6", corner: .bottomRight, alignment: .vertical, color: color)
            self.s7 = Segment(name: "s7", corner: .bottomLeft, alignment: .horizontal, color: color)
            self.s8 = Segment(name: "s8", corner: .bottomRight, alignment: .horizontal, color: color)
        }

        func setup(for size: CGSize, on positioningEntity: Entity) {
            let correction: Float = (Segment.thickness / 2.0) // correction to align lines perfectly

            for segment in all {
                segment.updateLength(with: size)
            }
            let horizontalSegmentLength = Float(size.width) / 2.0
            let verticalSegmentLength = Float(size.height) / 2.0

            s1.position += [-(horizontalSegmentLength / 2 - correction), 0, -(verticalSegmentLength - correction)]
            s2.position += [horizontalSegmentLength / 2 - correction, 0, -(verticalSegmentLength - correction)]
            s3.position += [-horizontalSegmentLength, 0, -verticalSegmentLength / 2]
            s4.position += [horizontalSegmentLength, 0, -verticalSegmentLength / 2]
            s5.position += [-horizontalSegmentLength, 0, verticalSegmentLength / 2]
            s6.position += [horizontalSegmentLength, 0, verticalSegmentLength / 2]
            s7.position += [-(horizontalSegmentLength / 2 - correction), 0, verticalSegmentLength - correction]
            s8.position += [horizontalSegmentLength / 2 - correction, 0, verticalSegmentLength - correction]

            for segment in all {
                positioningEntity.addChild(segment)
                segment.open()
            }
            positioningEntity.scale = .init(repeating: FocusRectangle.scaleForOpenSquare)

            //positioningEntity.scale = SIMD3<Float>(repeating: FocusRectangle.size * FocusRectangle.scaleForClosedSquare)
            // [0] is width, [2] is height
            //positioningEntity.scale = .init(x: 0.5, y: 1.0, z: 0.2)
        }
    }

    enum Corner {
        case topLeft // s1, s3
        case topRight // s2, s4
        case bottomRight // s6, s8
        case bottomLeft // s5, s7
    }

    /// aligment on 2D plane
    enum Alignment {
        case horizontal // s1, s2, s7, s8
        case vertical // s3, s4, s5, s6
    }

    enum Direction {
        case up, down, left, right

        var reversed: Direction {
            switch self {
            case .up:   return .down
            case .down: return .up
            case .left:  return .right
            case .right: return .left
            }
        }
    }

    class Segment: Entity, HasModel {

        // MARK: - Configuration & Initialization

        /// Thickness of the focus square lines in m.
        static let thickness: Float = 0.005

        /// Length of the focus square lines in m.
        private var closedLength: Float = 0.5  // segment length

        /// Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
        private var openLength: Float {
            closedLength / 2.0
        }

        let corner: Corner
        let alignment: Alignment
        var plane: ModelComponent

        init(name: String, corner: Corner, alignment: Alignment, color: Material.Color) {
            self.corner = corner
            self.alignment = alignment
            self.plane = ModelComponent(mesh: .generatePlane(width: 1.0, depth: 1.0), materials: [UnlitMaterial(color: color)])

            super.init()

            switch alignment {
            case .vertical:   self.scale = [Segment.thickness, 1.0, closedLength]
            case .horizontal: self.scale = [closedLength, 1.0, Segment.thickness]
            }

            self.name = name
            self.model = plane
        }

        required init() {
            fatalError("init() has not been implemented")
        }

        // MARK: - Animating Open/Closed

        var openDirection: Direction {
            switch (corner, alignment) {
            case (.topLeft, .horizontal):     return .left
            case (.topLeft, .vertical):       return .up
            case (.topRight, .horizontal):    return .right
            case (.topRight, .vertical):      return .up
            case (.bottomLeft, .horizontal):  return .left
            case (.bottomLeft, .vertical):    return .down
            case (.bottomRight, .horizontal): return .right
            case (.bottomRight, .vertical):   return .down
            }
        }

        func updateLength(with rectangleSize: CGSize) {
            let sideLength = (alignment == .horizontal) ? rectangleSize.width : rectangleSize.height
            closedLength = Float(sideLength) / 2.0
        }

        func open() {
            if alignment == .horizontal {
                scale[0] = openLength
            } else {
                scale[2] = openLength
            }

            let offset = (closedLength / 2.0) - (openLength / 2.0)
            updatePosition(withOffset: Float(offset), for: openDirection)
        }

        func close() {
            let oldLength: Float
            if alignment == .horizontal {
                oldLength = self.scale[0]
                self.scale[0] = closedLength
            } else {
                oldLength = self.scale[2]
                self.scale[2] = closedLength
            }

            let offset = closedLength / 2 - oldLength / 2
            updatePosition(withOffset: offset, for: openDirection.reversed)
        }

        private func updatePosition(withOffset offset: Float, for direction: Direction) {
            switch direction {
            case .left:     position.x -= offset
            case .right:    position.x += offset
            case .up:       position.z -= offset
            case .down:     position.z += offset
            }
        }
    }
}
