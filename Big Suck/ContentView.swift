//
//  ContentView.swift
//  Big Suck
//
//  Created by Izzy Fraimow on 5/5/24.
//

import SwiftUI
import CoreGraphics
import ScreenCaptureKit
import QuickLook

func lerp(start: Double, end: Double, t: Double) -> Double {
    return start + Double(t) * (end - start)
}

func lerp(start: CGPoint, end: CGPoint, t: Double) -> CGPoint {
    let point = CGPoint(
        x: lerp(start: start.x, end: end.x, t: t),
        y: lerp(start: start.y, end: end.y, t: t)
    )
    
    return point
}

struct DroppedItem {
    var location: CGPoint
    var image: NSImage
    var spiral: Spiral
}

struct ContentView: View {
    @State var tokens = [Any]()
    
    @State var capture: NSImage? = nil
    @State var dragStartTime: Date? = nil
    @State var dragReleaseTime: Date? = nil
    @State var isDragging = false
    @State var isAnimating = false
    @State var droppedItem: DroppedItem? = nil
    @State var spiral: Spiral? = nil
    @State var starSpin = false
    @State var isDropping = false
    @State var animationEndTime: Date? = nil
    
    let openSpring = Spring.bouncy
    let closeSpring = Spring.snappy
    
    let radius = 200.0
    
    /// Spring value in unit points
    func springPosition(at date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate
        let startTime = dragStartTime?.timeIntervalSinceReferenceDate ?? 0
        let endTime = animationEndTime?.timeIntervalSinceReferenceDate ?? 0
        let dragDuration = max(time - startTime, 0)
        let timeSinceEnd = max(time - endTime, 0)
        
        if isDragging {
            return openSpring.value(target: 1.0, time: dragDuration)
        } else {
            return 1 - min(closeSpring.value(target: 1.0, time: timeSinceEnd), 1)
        }
    }
    
    // `SCScreenshotManager.captureImage` is modern but captures images in a compressed color space
    // There may be a configuration option to correct this, but I haven't figured it out
    //    func captureWallpaper() async {
    //        do {
    //            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    //            let wallpaperWindows = content.windows.filter { window in
    //                window.owningApplication?.bundleIdentifier == "com.apple.dock" &&
    //                window.title?.starts(with: "Wallpaper") ?? false
    //            }
    //            let window = wallpaperWindows.first!
    //
    //            let filter = SCContentFilter(desktopIndependentWindow: window)
    //
    //            let streamConfig = SCStreamConfiguration()
    //            streamConfig.showsCursor = false
    //            streamConfig.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
    //            streamConfig.colorSpaceName = CGColorSpace.displayP3
    //            let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
    //            streamConfig.width = Int(window.frame.width * screenScale)
    //            streamConfig.height = Int(window.frame.height * screenScale)
    //
    //            let image = try await SCScreenshotManager.captureImage(
    //                contentFilter: filter,
    //                configuration: streamConfig
    //            )
    //            let imageSize = CGSize(width: image.width, height: image.height)
    //
    //            capture = NSImage(cgImage: image, size: imageSize)
    //        } catch {
    //
    //        }
    //    }
    
    // `CGWindowListCreateImage` works perfectly but is deprecated
    // This also has the benefit of not triggering a TCC alert
    func cgCaptureWallpaper() async {
        guard let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[ String : Any]] else { return }
        
        let wallpaperWindowIDs = info.compactMap { dict in
            if let ownerName = dict[kCGWindowOwnerName as String] as? String,
               let layer = dict[kCGWindowLayer as String] as? Int,
               let id = dict[kCGWindowNumber as String] as? Int {
                if ownerName == "Dock" && layer <= CGWindowLevelForKey(.desktopWindow) {
                    return id
                }
            }
            
            return nil
        }
        
        guard let id = wallpaperWindowIDs.first else { return }
        
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(id),
            .boundsIgnoreFraming
        ) else {
            return
        }
        
        let imageSize = CGSize(width: image.width, height: image.height)
        
        capture = NSImage(cgImage: image, size: imageSize)
    }
    
    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let springValue = springPosition(at: Date.now)
            ZStack {
                if let capture {
                    Image(nsImage: capture)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .visualEffect { content, proxy in
                            content
                                .distortionEffect(ShaderLibrary.discWarp(
                                    .float2(proxy.size),
                                    .float(radius * springValue),
                                    .float2(proxy.size.width / 2.0, proxy.size.height / 2.0)
                                ), maxSampleOffset: .zero)
                        }
                }
                
                Space(paused: !isAnimating)
                    .overlay {
                        GeometryReader { geometry in
                            Color.clear
                                .dropDestination(for: URL.self) {
                                    items, location in
                                    guard !isDropping else { return false }
                                    guard let firstItem = items.first else {
                                        print("what")
                                        return false
                                    }
                                    isDropping = true
                                    clearPasteboard()
                                    droppedItem = nil
                                    let center = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
                                    Task {
                                        await getDropPreview(url: firstItem, location: location, center: center)
                                    }
                                    return true
                                }
                        }
                    }
                    .mask {
                        Circle()
                            .frame(width: 2 * radius * springValue)
                    }
                    .overlay {
                        Circle()
                            .foregroundStyle(EllipticalGradient(colors: [.clear, .black], startRadiusFraction: 0.0, endRadiusFraction: 1.0))
                            .frame(width: 2 * radius * springValue)
                            .opacity(springValue)
                    }
                
                if let droppedItem, let dragReleaseTime {
                    GeometryReader { geometry in
                        let elapsedTime = Date.now.timeIntervalSinceReferenceDate - dragReleaseTime.timeIntervalSinceReferenceDate
                        let percent = elapsedTime / (droppedItem.spiral.endTheta) + 0.001
                        let (point, distance) = droppedItem.spiral.value(at: percent)
                        let distancePercent = distance / radius
                        Image(nsImage: droppedItem.image)
                            .position(point)
                            .opacity(1.0 - percent)
                            .scaleEffect(distancePercent)
                            .onChange(of: percent) {
                                if distancePercent < 0.04 && !starSpin {
                                    withAnimation(.linear(duration: 4.0)) {
                                        starSpin.toggle()
                                    } completion: {
                                        animationEndTime = .now
                                        reset()
                                    }
                                }
                            }
                    }
                    .visualEffect { content, proxy in
                        content
                            .distortionEffect(
                                ShaderLibrary.swirl(
                                    .float2(proxy.size),
                                    .float(radius / 4),
                                    .float2(proxy.size.width / 2.0, proxy.size.height / 2.0)
                                ),
                                maxSampleOffset: CGSize(width: 100, height: 100)
                            )
                    }
                }
                
                StarView(trigger: starSpin)
                    .frame(width: 60, height: 60)
            }
        }
        .onAppear {
            clearPasteboard()
            
            for window in NSApplication.shared.windows {
                window.level = NSWindow.Level(rawValue:  Int(CGWindowLevelForKey(CGWindowLevelKey.desktopWindow) - 1))
                window.styleMask = [.borderless, .nonactivatingPanel]
            }
            
            if tokens.isEmpty {
                tokens += [
                    NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { event in
                        if !isDragging {
                            guard isValidPasteboard() else { return }
                            Task { await cgCaptureWallpaper() }
                            isAnimating = true
                            isDragging = true
                            dragStartTime = Date.now
                            dragReleaseTime = nil
                        }
                    }!,
                    NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { event in
                        guard !isDropping else { return }
                        guard isValidPasteboard() else { return }
                        dragReleaseTime = Date.now
                    }!
                ]
            }
        }
    }
    
    func isValidPasteboard() -> Bool {
        guard let items = NSPasteboard(name: .drag).pasteboardItems else { return false }
        let types = items.flatMap(\.types)
        guard types.contains(.fileURL) else { return false }
        return true
    }
    
    func clearPasteboard() {
        // The drag pasteboard seems to have some amount of hysteresis so we have to explicitly clear it before we check
        // otherwise we'll get false positives
        // this surely will cause no problems
        NSPasteboard(name: .drag).clearContents()
    }
    
    func previewIcon(at url: URL) -> NSImage {
        let size = CGSize(width: 64, height: 64)
        let options: [CFString: Any] = [kQLThumbnailOptionIconModeKey: kCFBooleanTrue!]
        
        if let preview = QLThumbnailImageCreate(
            kCFAllocatorDefault,
            url as CFURL,
            size,
            options as CFDictionary
        )?.takeUnretainedValue() {
            let bitmapImageRep = NSBitmapImageRep.init(cgImage: preview)
            let newImage = NSImage.init(size: bitmapImageRep.size)
            newImage.addRepresentation(bitmapImageRep)
            
            //            bitmapImageRep.release()
            
            return newImage
        } else {
            return NSWorkspace.shared.icon(forFile: url.relativePath)
        }
    }
    
    func getDropPreview(url: URL, location: CGPoint, center: CGPoint) async {
        let image = previewIcon(at: url)
        let item = DroppedItem(
            location: location,
            image: image,
            spiral: Spiral(b: 0.1, center: center, target: location)
        )
        droppedItem = item
        
    }
    
    func reset() {
        isDragging = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + closeSpring.settlingDuration) {
            guard !isDragging else { return }
            guard !isDropping else { return }
    
            capture = nil
            dragStartTime = nil
            dragReleaseTime = nil
            isAnimating = false
            droppedItem = nil
            spiral = nil
            isDropping = false
        }
    }
}


#Preview {
    ContentView()
}
