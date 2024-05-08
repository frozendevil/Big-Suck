//
//  Space.swift
//  Big Suck
//
//  Created by Izzy Fraimow on 5/6/24.
//

import SwiftUI

// Particle system more-or-less verbatim from Paul + Sophie Hudson's "Making it Rain – Advanced Special Effects with SwiftUI" talk
// https://www.youtube.com/watch?v=H-kWbiPqjuM

extension Double {
    func spread() -> Self {
        Self.random(in: -self / 2...self / 2)
    }
}

struct Particle {
    var position: SIMD2<Double>
    var speed: SIMD2<Double>
    
    var birthTime: Double
    var lifespan: Double
    var startSize: Double
    var size = 0.0
    var opacity = 1.0
    var attack = 0.5
    var release = 2.0
    var color: Color
}

class ParticleSystem {
    var particles = [Particle]()
    var position = SIMD2(0.5, 0.5)
    
    var spawnRadius = 0.0
    
    var lifespan = 1.0
    var speed = 1.0
    var size = 1.0
    var attack = 1.5
    var release = 4.0
    
    var maxOpacity = 1.0
    
    var speedVary = 0.0
    var lifeVary = 0.0
    var sizeVary = 0.0
    var attackVary = 0.2
    var releaseVary = 1.0
    
    var probability = 1.0
    
    var sizeAtDeath = 1.0
    
    var colors = [Color.white]
    var mode = GraphicsContext.BlendMode.color
    
    var lastUpdate = Date.now.timeIntervalSinceReferenceDate
    
    func createParticle(seed: Bool = false) {
        guard (0...probability).contains(Double.random(in: 0...1)) else { return }
        let launchAngle = Double.random(in: 0...Double.pi * 2.0)
        
        let launchSpeed = speed + speedVary.spread()
        let lifespan = lifespan + lifeVary.spread()
        let size = size + sizeVary.spread()
        
        let xSpeed = cos(launchAngle) * launchSpeed
        let ySpeed = sin(launchAngle) * launchSpeed
        
        let r = spawnRadius * sqrt(Double.random(in: 0...1.0))
        let theta = Double.random(in: 0...1.0) * 2.0 * Double.pi
        let origin = SIMD2(
            position.x + r * cos(theta),
            position.y + r * sin(theta)
        )
        
        let attack = attack + attackVary.spread()
        let release = release + releaseVary.spread()
        
        let newParticle = Particle(
            position: origin,
            speed: [xSpeed, ySpeed],
            birthTime: seed ? lastUpdate - attack : lastUpdate,
            lifespan: lifespan,
            startSize: size,
            attack: attack,
            release: release, 
            color: colors.randomElement()!
        )
        
        particles.append(newParticle)
    }
    
    func update(date: Date, forceDelta: Double? = nil) {
        createParticle(seed: forceDelta != nil)
        
        let current = Date.now.timeIntervalSinceReferenceDate
        let delta = forceDelta ?? current - lastUpdate
        lastUpdate = current
        
        particles = particles.compactMap {
            var copy = $0
            copy.position += copy.speed * delta
            
            let age = current - copy.birthTime
            if age < copy.attack {
                copy.opacity = (age / copy.attack) * maxOpacity
            } else {
                copy.opacity = (1 - (age - copy.attack) / copy.release) * maxOpacity
            }
            
            guard copy.position.x < 1.1, copy.position.x > -0.1,
                  copy.position.y < 1.1,
                  copy.position.y > -0.1 else {
                return nil
            }
            
            let progress = age / copy.lifespan
            let targetSize = copy.startSize * sizeAtDeath
            let gap = targetSize - copy.startSize
            copy.size = copy.startSize + (gap * progress)
            return copy
        }
    }
    
    func seed(duration: TimeInterval = 2.0) {
        let seedTime = lastUpdate - duration
        let step = 1.0 / 60.0
        for time in stride(from: seedTime, to: lastUpdate, by: step) {
            update(date: Date(timeIntervalSinceReferenceDate: time), forceDelta: step)
        }
    }
}

struct ParticleView: View {
    @State private var system: ParticleSystem
    var image: ImageResource
    var paused: Bool
    
    public init(system: ParticleSystem, image: ImageResource, paused: Bool) {
        _system = State(initialValue: system)
        self.image = image
        self.paused = paused
    }
    
    var body: some View {
        TimelineView(.animation(paused: paused)) { timeline in
            Canvas { context, size in
                system.update(date: timeline.date)
                draw(system, into: context, at: size)
            }
        }
    }
    
    func draw(
        _ system: ParticleSystem,
        into context: GraphicsContext,
        at size: CGSize
    ) {
        for p in system.particles {
            let x = p.position.x * size.width
            let y = p.position.y * size.height
            var c = context
            c.addFilter(.colorMultiply(p.color))
            c.blendMode = system.mode
            c.translateBy(x: x, y: y)
            c.scaleBy(
                x: p.size,
                y: p.size
            )
            c.opacity = p.opacity
            c.draw(Image(image), at: .zero)
        }
    }
}
struct Space: View {
    static func createStarSystem() -> ParticleSystem {
        let system = ParticleSystem()
        system.speed = 0.1
        system.speedVary = 0.1
        system.size = 0.1
        system.sizeVary = 0.1
        system.lifespan = 2.0
        system.lifeVary = 0.5
        return system
    }
    
    static func createSpaceSystem() -> ParticleSystem {
        let system = ParticleSystem()
        system.probability = 0.1
        system.spawnRadius = 0.2
        system.size = 4.0
        system.sizeVary = 2.0
        system.speed = 0.01
        system.speedVary = 0.1
        system.maxOpacity = 0.6
        system.lifespan = 5.0
        system.lifeVary = 0.5
        system.attack = 10.0
        system.attackVary = 2.0
        system.release = 10.0
        system.releaseVary = 3.0
        system.colors = [
            Color(red: 0.20, green: 0.01, blue: 0.46),
            Color(red: 0.16, green: 0.08, blue: 0.58),
            Color(red: 0.17, green: 0.01, blue: 0.25),
            Color(red: 0.29, green: 0.16, blue: 0.35),
            Color(red: 0.04, green: 0.03, blue: 0.21),
            Color(red: 0.04, green: 0.02, blue: 0.46),
        ]
//        system.mode = .multiply
        
        return system
    }
    
    @State var starSystem  = Self.createStarSystem()
    @State var spaceSystem = Self.createSpaceSystem()
    var paused: Bool
    
    var body: some View {
        ZStack {
            Color.black
            
            ParticleView(system: spaceSystem, image: .blur08, paused: paused)
            ParticleView(system: starSystem, image: .blur01, paused: paused)
        }
        .ignoresSafeArea()
        .onChange(of: paused) {
            guard !paused else { return }
            starSystem.seed()
            spaceSystem.seed(duration: 10)
        }
    }
}

#Preview {
    Space(paused: false)
}
