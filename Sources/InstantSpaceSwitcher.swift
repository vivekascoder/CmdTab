import Cocoa
import CoreGraphics
import Darwin

enum InstantSpaceSwitcher {
    private typealias CGSConnectionID = Int32
    private typealias CGSSpaceID = UInt64
    private typealias CGSMainConnectionIDFunction = @convention(c) () -> CGSConnectionID
    private typealias CGSGetActiveSpaceFunction = @convention(c) (CGSConnectionID) -> CGSSpaceID
    private typealias CGSCopyManagedDisplaySpacesFunction = @convention(c) (CGSConnectionID, CFString?) -> Unmanaged<CFArray>?
    private typealias CGSCopySpacesForWindowsFunction = @convention(c) (CGSConnectionID, Int32, CFArray) -> Unmanaged<CFArray>?

    enum Direction {
        case left
        case right
    }

    private static let cgsEventTypeField = CGEventField(rawValue: 55)!
    private static let gestureHIDTypeField = CGEventField(rawValue: 110)!
    private static let gestureSwipeMotionField = CGEventField(rawValue: 123)!
    private static let gestureSwipeProgressField = CGEventField(rawValue: 124)!
    private static let gestureSwipeVelocityXField = CGEventField(rawValue: 129)!
    private static let gestureSwipeVelocityYField = CGEventField(rawValue: 130)!
    private static let gesturePhaseField = CGEventField(rawValue: 132)!

    private static let cgsEventDockControl: Int64 = 30
    private static let hidEventDockSwipe: Int64 = 23
    private static let gestureMotionHorizontal: Int64 = 1
    private static let gesturePhaseBegan: Int64 = 1
    private static let gesturePhaseChanged: Int64 = 2
    private static let gesturePhaseEnded: Int64 = 4
    private static let gestureVelocity = 2_000.0
    private static let workspaceWrapStepDelay: TimeInterval = 0.11
    private static var workspaceSwitchInProgress = false

    private struct WorkspacePosition {
        let index: Int
        let count: Int
    }

    static func activate(_ app: NSRunningApplication) {
        guard AppSettings.shared.instantSpaceSwitching else {
            app.activate()
            return
        }

        if switchToSpace(containing: app) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                app.activate()
            }
        } else {
            app.activate()
        }
    }

    static func switchWorkspace(_ direction: Direction) {
        guard !workspaceSwitchInProgress else { return }

        guard let position = currentWorkspacePosition(), position.count > 1 else {
            _ = postDockSwipe(direction: direction)
            return
        }

        let lastIndex = position.count - 1
        let move: (direction: Direction, steps: Int)

        switch direction {
        case .right:
            move = position.index == lastIndex ? (.left, lastIndex) : (.right, 1)
        case .left:
            move = position.index == 0 ? (.right, lastIndex) : (.left, 1)
        }

        postWorkspaceSwipes(direction: move.direction, steps: move.steps)
    }

    private static func switchToSpace(containing app: NSRunningApplication) -> Bool {
        guard let connection = mainConnectionID(),
              let activeSpaceID = activeSpaceID(connection: connection),
              let targetSpaceID = spaceID(for: app, connection: connection),
              targetSpaceID != activeSpaceID,
              let indexes = currentDisplaySpaceIndexes(connection: connection, activeSpaceID: activeSpaceID),
              let currentIndex = indexes[activeSpaceID],
              let targetIndex = indexes[targetSpaceID] else {
            return false
        }

        let direction: Direction = targetIndex > currentIndex ? .right : .left
        for _ in 0..<abs(targetIndex - currentIndex) {
            guard postDockSwipe(direction: direction) else { return false }
        }
        return true
    }

    private static func mainConnectionID() -> CGSConnectionID? {
        guard let symbol = dlsym(dlopen(nil, RTLD_LAZY), "CGSMainConnectionID") else { return nil }
        let function = unsafeBitCast(symbol, to: CGSMainConnectionIDFunction.self)
        let connection = function()
        return connection == 0 ? nil : connection
    }

    private static func activeSpaceID(connection: CGSConnectionID) -> CGSSpaceID? {
        guard let symbol = dlsym(dlopen(nil, RTLD_LAZY), "CGSGetActiveSpace") else { return nil }
        let function = unsafeBitCast(symbol, to: CGSGetActiveSpaceFunction.self)
        let spaceID = function(connection)
        return spaceID == 0 ? nil : spaceID
    }

    private static func spaceID(for app: NSRunningApplication, connection: CGSConnectionID) -> CGSSpaceID? {
        let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let windowIDs = windows.compactMap { info -> NSNumber? in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == app.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let windowID = info[kCGWindowNumber as String] as? NSNumber else {
                return nil
            }
            return windowID
        }

        guard !windowIDs.isEmpty,
              let symbol = dlsym(dlopen(nil, RTLD_LAZY), "CGSCopySpacesForWindows") else {
            return nil
        }

        let function = unsafeBitCast(symbol, to: CGSCopySpacesForWindowsFunction.self)
        guard let unmanaged = function(connection, 7, windowIDs as CFArray) else { return nil }
        let spaces = unmanaged.takeRetainedValue() as NSArray
        return spaces.compactMap { ($0 as? NSNumber)?.uint64Value }.first
    }

    private static func currentDisplaySpaceIndexes(
        connection: CGSConnectionID,
        activeSpaceID: CGSSpaceID
    ) -> [CGSSpaceID: Int]? {
        guard let symbol = dlsym(dlopen(nil, RTLD_LAZY), "CGSCopyManagedDisplaySpaces") else { return nil }
        let function = unsafeBitCast(symbol, to: CGSCopyManagedDisplaySpacesFunction.self)
        guard let unmanaged = function(connection, nil) else { return nil }
        let displays = unmanaged.takeRetainedValue() as NSArray

        for display in displays {
            guard let displayDict = display as? NSDictionary,
                  let spaces = displayDict["Spaces"] as? [NSDictionary] else {
                continue
            }

            var result: [CGSSpaceID: Int] = [:]
            for space in spaces {
                guard let id = (space["id64"] as? NSNumber)?.uint64Value else { continue }
                result[id] = result.count
            }

            if result[activeSpaceID] != nil {
                return result
            }
        }

        return nil
    }

    private static func currentWorkspacePosition() -> WorkspacePosition? {
        guard let connection = mainConnectionID(),
              let activeSpaceID = activeSpaceID(connection: connection),
              let indexes = currentDisplaySpaceIndexes(connection: connection, activeSpaceID: activeSpaceID),
              let currentIndex = indexes[activeSpaceID] else {
            return nil
        }

        return WorkspacePosition(index: currentIndex, count: indexes.count)
    }

    private static func postWorkspaceSwipes(direction: Direction, steps: Int) {
        guard steps > 0 else { return }

        if steps == 1 {
            _ = postDockSwipe(direction: direction)
            return
        }

        workspaceSwitchInProgress = true
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + workspaceWrapStepDelay * Double(step)) {
                _ = postDockSwipe(direction: direction)
                if step == steps - 1 {
                    workspaceSwitchInProgress = false
                }
            }
        }
    }

    private static func postDockSwipe(direction: Direction) -> Bool {
        postDockSwipePhase(gesturePhaseBegan, direction: direction)
            && postDockSwipePhase(gesturePhaseChanged, direction: direction)
            && postDockSwipePhase(gesturePhaseEnded, direction: direction)
    }

    private static func postDockSwipePhase(_ phase: Int64, direction: Direction) -> Bool {
        guard let event = CGEvent(source: nil) else { return false }

        let isRight = direction == .right
        let progress = isRight ? Double(Float.leastNonzeroMagnitude) : -Double(Float.leastNonzeroMagnitude)
        let velocity = isRight ? gestureVelocity : -gestureVelocity

        event.setIntegerValueField(cgsEventTypeField, value: cgsEventDockControl)
        event.setIntegerValueField(gestureHIDTypeField, value: hidEventDockSwipe)
        event.setIntegerValueField(gesturePhaseField, value: phase)
        event.setDoubleValueField(gestureSwipeProgressField, value: progress)
        event.setIntegerValueField(gestureSwipeMotionField, value: gestureMotionHorizontal)
        event.setDoubleValueField(gestureSwipeVelocityXField, value: velocity)
        event.setDoubleValueField(gestureSwipeVelocityYField, value: velocity)
        event.post(tap: .cgSessionEventTap)
        return true
    }
}
