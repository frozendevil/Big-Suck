//
//  StarView.swift
//  Big Suck
//
//  Created by Izzy Fraimow on 5/8/24.
//

import SwiftUI

struct StarView: View {
    var trigger: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(EllipticalGradient(colors:[.yellow, .yellow.opacity(0.0)]))
            
            Image(.shine)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.yellow)
        }
        .phaseAnimator([0, 1, 2], trigger: trigger) { view, phase in
                view
                    .scaleEffect(phase == 1 ? 1.0 : 0.0)
                    .opacity(phase == 1 ? 1 : 0)
                    .animation(phase == 1 ? .easeIn(duration: 2.0) : .easeOut(duration: 2.0), value: phase)
        }
        .rotationEffect(trigger ? .radians(.pi * 1.6) : .zero)
    }
}

#Preview {
    StarView()
}
