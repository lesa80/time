import AppKit

@MainActor
func checkScrollRotation(library: ThemeLibrary) throws {
    // Real CG scroll events, delivered only to our own unshown windows.
    // They are never posted to the system and do not move the user's pointer.
    for id in ["jlc-memovox-parking", "breitling-navitimer"] {
        let renderer = try library.renderer(for: id)
        let window = ClockWindow(contentRect: NSRect(x: 200, y: 200, width: 280, height: 280), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        var rotations: [Double] = [], clicks = 0, moves = 0, haptics = 0
        let view = ClockView(renderer: renderer, hapticFeedback: { _ in haptics += 1 })
        window.contentView = view
        view.onRotation = { rotations.append($0) }
        view.onInteraction = { _ in clicks += 1 }
        view.onDragEnded = { moves += 1 }
        defer { view.onRotation = nil; view.onInteraction = nil; view.onDragEnded = nil; view.endPointerHover(); window.close() }
        func scroll(at point: NSPoint, x: Int32 = 0, y: Int32 = 0, precise: Bool = true, momentum: Int64 = 0, phase: Int64 = 2) -> NSEvent {
            let event = CGEvent(scrollWheelEvent2Source: nil, units: precise ? .pixel : .line, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0)!
            let screen = window.convertPoint(toScreen: point)
            let desktopTop = NSScreen.screens.first!.frame.maxY
            event.location = CGPoint(x: screen.x, y: desktopTop - screen.y)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: precise ? 1 : 0)
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
            return NSEvent(cgEvent: event)!
        }
        func hover(at point: NSPoint) {
            let event = NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
            window.sendEvent(event)
        }
        for width: CGFloat in [180, 280, 466] {
            view.showBezel = true
            window.setContentSize(renderer.displaySize(width: width, showBezel: true)); view.layoutSubtreeIfNeeded()
            let frame = window.frame
            let point: NSPoint
            if let ring = view.subviews.compactMap({ $0 as? RotaryRing }).first {
                // Test the metal rim beyond the glass, not just the printed scale.
                point = ring.convert(NSPoint(x: ring.bounds.midX, y: ring.bounds.height * 0.99), to: nil)
            } else {
                let crown = view.subviews.compactMap { $0 as? MechanicalButton }.first!
                point = crown.convert(NSPoint(x: crown.bounds.midX, y: crown.bounds.midY), to: nil)
            }
            rotations.removeAll()
            let vertical = scroll(at: point, y: 20)
            expect(vertical.hasPreciseScrollingDeltas && !window.isKeyWindow, "Use a real high-resolution event in a non-key desktop window")
            window.sendEvent(vertical)
            expect(rotations == [-10], "Hover + vertical trackpad scroll must rotate once without clicking at every size: \(id), \(width), event=\(vertical.locationInWindow)")
            window.sendEvent(scroll(at: point, x: 20))
            expect(rotations.last == -10 && rotations.count == 2, "Horizontal trackpad scrolling must also rotate")
            window.sendEvent(scroll(at: point, y: -20))
            expect(rotations.last == 10, "Reversing the gesture must reverse rotation")
            window.sendEvent(scroll(at: point, x: 12, y: 3))
            expect(rotations.last == -6, "Diagonal gestures must use one dominant axis")
            window.sendEvent(scroll(at: point, y: 1))
            expect(rotations.last == -0.5, "Precise trackpad deltas must retain sub-degree movement")
            let count = rotations.count
            window.sendEvent(scroll(at: point, y: 20, momentum: 2))
            window.sendEvent(scroll(at: point, y: 20, phase: 4))
            window.sendEvent(scroll(at: point, y: 20, phase: 8))
            expect(rotations.count == count, "Inertia, ended and cancelled phases must not spin the mechanism")
            window.sendEvent(scroll(at: point, y: 1, precise: false))
            expect(rotations.last == -3 && rotations.count == count + 1, "A mouse-wheel notch also rotates the same mechanism")
            let beforeOutside = rotations.count
            let center = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
            window.sendEvent(scroll(at: center, y: 20))
            window.sendEvent(scroll(at: NSPoint(x: -10, y: -10), y: 20))
            expect(rotations.count == beforeOutside, "Moving away from the part must stop a latched gesture")
            window.ignoresMouseEvents = true
            window.sendEvent(scroll(at: point, y: 20))
            expect(rotations.count == beforeOutside, "A locked clock must not rotate")
            window.ignoresMouseEvents = false
            expect(window.frame == frame && moves == 0 && clicks == 0 && !window.isKeyWindow,
                   "Scrolling must never move the clock, activate it or click its pusher/crown")
            if let ring = view.subviews.compactMap({ $0 as? RotaryRing }).first {
                view.endPointerHover(); let beforeHover = haptics
                hover(at: center)
                expect(haptics == beforeHover, "The square bounding box must not cause hover feedback over the dial center")
                hover(at: point); hover(at: point)
                expect(haptics == beforeHover + 1 && NSCursor.current == .pointingHand, "The actual bezel must establish hover once")
                let upper = view.subviews.compactMap { $0 as? MechanicalButton }.first!
                let pusher = upper.convert(NSPoint(x: upper.bounds.midX, y: upper.bounds.midY), to: nil)
                window.sendEvent(scroll(at: pusher, y: 20))
                expect(rotations.count == beforeOutside, "A chronograph pusher does not rotate")
                ring.isEnabled = false
                window.sendEvent(scroll(at: point, y: 20))
                expect(rotations.count == beforeOutside, "A disabled bezel must ignore scrolling")
                ring.isEnabled = true
                view.showBezel = false
                window.setContentSize(renderer.displaySize(width: width, showBezel: false)); view.layoutSubtreeIfNeeded()
                let barePoint = ring.convert(NSPoint(x: ring.bounds.midX, y: ring.bounds.height * 0.95), to: nil)
                window.sendEvent(scroll(at: barePoint, y: 20))
                expect(rotations.count == beforeOutside + 1, "The visible calculation scale remains usable without the case")
            } else {
                let crown = view.subviews.compactMap { $0 as? MechanicalButton }.first!
                crown.isEnabled = false
                window.sendEvent(scroll(at: point, y: 20))
                expect(rotations.count == beforeOutside, "A disabled crown must not rotate")
                crown.isEnabled = true
                view.showBezel = false
                window.sendEvent(scroll(at: point, y: 20))
                expect(rotations.count == beforeOutside, "A hidden crown has no scroll hit area")
            }
        }
    }
    print("Passed: hover-only trackpad scroll routing, both axes/reversal/fractional deltas, metal rim/three sizes, no focus/click/drag, no momentum, wheel, hidden/disabled/locked controls and bare slide rule")
}
