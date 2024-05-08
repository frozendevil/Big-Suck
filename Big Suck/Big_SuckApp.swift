//
//  Big_SuckApp.swift
//  Big Suck
//
//  Created by Izzy Fraimow on 5/5/24.
//

import SwiftUI

class TransparentWindowView: NSView {
    override func viewDidMoveToWindow() {
        window?.backgroundColor = .clear
        super.viewDidMoveToWindow()
    }
}

struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView { return TransparentWindowView() }
    func updateNSView(_ nsView: NSView, context: Context) { }
}

@main
struct Big_SuckApp: App {
    var body: some Scene {
        WindowGroup {
            let screen = NSScreen.main!
            let height = screen.frame.height - screen.visibleFrame.height - (screen.visibleFrame.origin.y - screen.frame.origin.y)
            ContentView()
                .frame(width: screen.frame.size.width, height: screen.frame.size.height)
                .offset(y: -ceil(height/screen.backingScaleFactor))
                .background(TransparentWindow())
        }
    }
}
