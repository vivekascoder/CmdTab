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

    struct WorkspacePosition {
        let index: Int
        let count: Int

        var desktopNumber: Int {
            index + 1
        }
    }

    private struct WorkspaceDisplaySpaces {
        let spaces: [ManagedSpace]
        let activeIndex: Int
    }

    private struct ManagedSpace {
        private static let fullscreenType = 1
        private static let tiledType = 4

        let id: CGSSpaceID
        let type: Int

        var isFullscreenLike: Bool {
            type == Self.fullscreenType || type == Self.tiledType
        }
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

    @discardableResult
    static func switchWorkspace(_ direction: Direction) -> WorkspacePosition? {
        guard let position = currentWorkspacePosition(), position.count > 1 else {
            _ = postDockSwipe(direction: direction)
            return nil
        }

        let lastIndex = position.count - 1
        let move: (direction: Direction, steps: Int)
        let nextIndex: Int

        switch direction {
        case .right:
            move = position.index == lastIndex ? (.left, lastIndex) : (.right, 1)
            nextIndex = position.index == lastIndex ? 0 : position.index + 1
        case .left:
            move = position.index == 0 ? (.right, lastIndex) : (.left, 1)
            nextIndex = position.index == 0 ? lastIndex : position.index - 1
        }

        postWorkspaceSwipes(direction: move.direction, steps: move.steps)
        return WorkspacePosition(index: nextIndex, count: position.count)
    }

    @discardableResult
    static func switchWorkspace(toDesktopNumber desktopNumber: Int) -> WorkspacePosition? {
        guard desktopNumber > 0,
              let position = currentWorkspacePosition(),
              position.count > 1 else {
            return nil
        }

        let targetIndex = desktopNumber - 1
        guard targetIndex < position.count else { return nil }
        guard targetIndex != position.index else { return position }

        if targetIndex > position.index {
            postWorkspaceSwipes(direction: .right, steps: targetIndex - position.index)
        } else {
            postWorkspaceSwipes(direction: .left, steps: position.index - targetIndex)
        }

        return WorkspacePosition(index: targetIndex, count: position.count)
    }

    private static func switchToSpace(containing app: NSRunningApplication) -> Bool {
        guard let connection = mainConnectionID(),
              let activeSpaceID = activeSpaceID(connection: connection),
              let displaySpaces = currentDisplaySpaces(connection: connection, activeSpaceID: activeSpaceID),
              let targetSpaceID = spaceID(for: app, connection: connection, displaySpaces: displaySpaces),
              targetSpaceID != activeSpaceID else {
            return false
        }

        let indexes = currentDisplaySpaceIndexes(displaySpaces: displaySpaces)
        guard
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

    private static func spaceID(
        for app: NSRunningApplication,
        connection: CGSConnectionID,
        displaySpaces: WorkspaceDisplaySpaces
    ) -> CGSSpaceID? {
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
        let candidateIDs = orderedUniqueSpaceIDs(from: spaces)
        guard !candidateIDs.isEmpty else { return nil }

        let candidates = Set(candidateIDs)
        let displayCandidates = displaySpaces.spaces.filter { candidates.contains($0.id) }
        if let fullscreenSpace = displayCandidates.first(where: { $0.isFullscreenLike }) {
            return fullscreenSpace.id
        }

        return displayCandidates.first?.id ?? candidateIDs.first
    }

    private static func orderedUniqueSpaceIDs(from spaces: NSArray) -> [CGSSpaceID] {
        var result: [CGSSpaceID: Int] = [:]
        var orderedIDs: [CGSSpaceID] = []

        for space in spaces {
            guard let id = (space as? NSNumber)?.uint64Value,
                  result[id] == nil else {
                continue
            }
            result[id] = orderedIDs.count
            orderedIDs.append(id)
        }

        return orderedIDs
    }

    private static func currentDisplaySpaceIndexes(displaySpaces: WorkspaceDisplaySpaces) -> [CGSSpaceID: Int] {
        var result: [CGSSpaceID: Int] = [:]
        for space in displaySpaces.spaces {
            result[space.id] = result.count
        }
        return result
    }

    private static func currentDisplaySpaces(
        connection: CGSConnectionID,
        activeSpaceID: CGSSpaceID
    ) -> WorkspaceDisplaySpaces? {
        guard let symbol = dlsym(dlopen(nil, RTLD_LAZY), "CGSCopyManagedDisplaySpaces") else { return nil }
        let function = unsafeBitCast(symbol, to: CGSCopyManagedDisplaySpacesFunction.self)
        guard let unmanaged = function(connection, nil) else { return nil }
        let displays = unmanaged.takeRetainedValue() as NSArray

        for display in displays {
            guard let displayDict = display as? NSDictionary,
                  let spaces = displayDict["Spaces"] as? [NSDictionary] else {
                continue
            }

            let managedSpaces = spaces.compactMap { space -> ManagedSpace? in
                guard let id = (space["id64"] as? NSNumber)?.uint64Value else { return nil }
                let type = (space["type"] as? NSNumber)?.intValue ?? 0
                return ManagedSpace(id: id, type: type)
            }
            if let activeIndex = managedSpaces.firstIndex(where: { $0.id == activeSpaceID }) {
                return WorkspaceDisplaySpaces(
                    spaces: managedSpaces,
                    activeIndex: activeIndex
                )
            }
        }

        return nil
    }

    static func currentWorkspacePosition() -> WorkspacePosition? {
        guard let connection = mainConnectionID(),
              let activeSpaceID = activeSpaceID(connection: connection),
              let displaySpaces = currentDisplaySpaces(connection: connection, activeSpaceID: activeSpaceID) else {
            return nil
        }

        return WorkspacePosition(
            index: displaySpaces.activeIndex,
            count: displaySpaces.spaces.count
        )
    }

    private static func postWorkspaceSwipes(direction: Direction, steps: Int) {
        guard steps > 0 else { return }
        let velocity = gestureVelocity * Double(steps)
        for _ in 0..<steps {
            _ = postDockSwipe(direction: direction, velocity: velocity)
        }
    }

    private static func postDockSwipe(direction: Direction, velocity: Double = gestureVelocity) -> Bool {
        postDockSwipePhase(gesturePhaseBegan, direction: direction, velocity: velocity)
            && postDockSwipePhase(gesturePhaseChanged, direction: direction, velocity: velocity)
            && postDockSwipePhase(gesturePhaseEnded, direction: direction, velocity: velocity)
    }

    private static func postDockSwipePhase(_ phase: Int64, direction: Direction, velocity: Double) -> Bool {
        guard let event = CGEvent(source: nil) else { return false }

        let isRight = direction == .right
        let progress = isRight ? Double(Float.leastNonzeroMagnitude) : -Double(Float.leastNonzeroMagnitude)
        let signedVelocity = isRight ? velocity : -velocity

        event.setIntegerValueField(cgsEventTypeField, value: cgsEventDockControl)
        event.setIntegerValueField(gestureHIDTypeField, value: hidEventDockSwipe)
        event.setIntegerValueField(gesturePhaseField, value: phase)
        event.setDoubleValueField(gestureSwipeProgressField, value: progress)
        event.setIntegerValueField(gestureSwipeMotionField, value: gestureMotionHorizontal)
        event.setDoubleValueField(gestureSwipeVelocityXField, value: signedVelocity)
        event.setDoubleValueField(gestureSwipeVelocityYField, value: signedVelocity)
        event.post(tap: .cgSessionEventTap)
        return true
    }
}
