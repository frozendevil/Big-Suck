//
//  Spiral.swift
//  Big Suck
//
//  Created by Izzy Fraimow on 5/7/24.
//

import SwiftUI

func map(
    _ minRange: CGFloat,
    _ maxRange: CGFloat,
    _ minDomain: CGFloat,
    _ maxDomain: CGFloat,
    _ value: CGFloat
) ->  CGFloat {
    return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
}

extension CGPoint {
    static func -(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        let point = CGPoint(
            x: lhs.x - rhs,
            y: lhs.y - rhs
        )
        return point
    }
    
    func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
        return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    }
    
    func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt(CGPointDistanceSquared(from: from, to: to))
    }
    
    func distance(to: CGPoint) -> CGFloat {
        let distanceSquared = pow(self.x - to.x, 2.0) + pow(self.y - to.y, 2.0)
        let distance = sqrt(distanceSquared)
        return distance
    }
}

struct Spiral {
    /*
     r = a * exp(b * theta) * exp(-b * rot_theta)
     */
    
    var a = 1.0
    var b = 0.5
    var center: CGPoint
    var target: CGPoint
    
    let rotationTheta: CGFloat
    let endTheta: CGFloat // theta+rot_theta
    let r1: CGFloat
    
    init(a: Double = 1.0, b: Double = 0.5, center: CGPoint, target: CGPoint) {
        self.a = a
        self.b = b
        self.center = center
        self.target = target
        
        let radius = target.distance(to: center)
        let theta =  log(radius / a)/b
        let x = target.x - center.x
        let y = center.y - target.y
        var targetTheta = atan(y / x)
        if x < 0 {
            targetTheta = Double.pi + targetTheta
        } else if x > 0 && y < 0 {
            targetTheta = 2.0 * Double.pi + targetTheta
        }
        while a * exp(b * targetTheta) < radius {
            targetTheta = 2.0 * Double.pi + targetTheta
        }
        
        rotationTheta = targetTheta - theta
        endTheta = targetTheta
        r1 = exp(-b * rotationTheta)
    }
    
    func value(at: CGFloat) -> (CGPoint, CGFloat) {
        let i = map(1.0, 0.0, 0.0, endTheta, at)
        let r2 = exp(b * i)
        let x = center.x + a * r1 * r2 * cos(-i)
        let y = center.y + a * r1 * r2 * sin(-i)
        let point = CGPoint(x: x, y: y)
        let distance = point.distance(to: center)
        return (point, distance)
    }
}

struct SpiralView: View {
    @State var touch: CGPoint?
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            
            // Center
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        origin: center - 3.0,
                        size: CGSize(width: 6, height: 6)
                    )
                ),
                with: .color(.black)
            )
            
            if let touch {
                let spiral = Spiral(a: 1, b: 0.2, center: center, target: touch)
                
                for i in stride(from: 0, to: 1.0, by: 0.001) {
                    let (point, _) = spiral.value(at: i)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: point.x - 2,
                            y: point.y - 2,
                            width: 4,
                            height: 4
                        )),
                        with: .color(.green)
                    )
                }
                
                // Target
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            origin: touch - 3.0,
                            size: CGSize(width: 6, height: 6)
                        )
                    ),
                    with: .color(.red)
                )
            }
            
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    touch = gesture.location
                }
        )
    }
}

#Preview {
    SpiralView()
}
