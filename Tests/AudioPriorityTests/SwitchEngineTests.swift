import Foundation
import Testing
@testable import AudioPriorityCore

/// A small fake Mac: what is connected, what is ranked, what is current.
private struct Mac {
    var outputs = ["airpods", "speakers"]
    var inputs = ["dji", "airpods-mic", "mac-mic"]
    var hidden: Set<String> = []
    var current: [Role: String] = [.output: "speakers", .input: "dji"]
    var now: TimeInterval = 100
    var userPicking = false
    /// Rank order of everything the user has ever connected.
    var order: [Role: [String]] = [.output: ["airpods", "speakers"], .input: ["dji", "airpods-mic", "mac-mic"]]

    var input: SwitchEngine.Input {
        let connected: [Role: Set<String>] = [.output: Set(outputs), .input: Set(inputs)]
        let ranking = order.mapValues { [hidden] uids in uids.filter { !hidden.contains($0) } }
            .reduce(into: [Role: [String]]()) { result, pair in
                result[pair.key] = pair.value.filter { connected[pair.key]!.contains($0) }
            }
        return .init(ranking: ranking, connected: connected, current: current, now: now, userPicking: userPicking)
    }

    /// Sends an event and makes the switches the engine asks for, as the app would.
    @discardableResult
    mutating func send(_ event: SwitchEngine.Event, to engine: inout SwitchEngine) -> [SwitchEngine.Command] {
        let commands = engine.handle(event, input)
        for command in commands { current[command.role] = command.uid }
        if !commands.isEmpty { _ = engine.handle(.systemChanged, input) }
        return commands
    }
}

@Suite struct SwitchEngineTests {
    @Test func launchMovesToTheTopOfEachList() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        var engine = SwitchEngine(auto: true)
        let commands = mac.send(.systemChanged, to: &engine)
        #expect(commands == [.init(.output, "airpods"), .init(.input, "dji")])
    }

    @Test func launchWithAutoOffChangesNothing() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        var engine = SwitchEngine(auto: false)
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(engine.held == [.output: "speakers", .input: "mac-mic"])
    }

    @Test func airPodsConnectingTakeTheOutputButNotTheMicrophone() {
        var mac = Mac(outputs: ["speakers"], inputs: ["dji", "mac-mic"])
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)

        // AirPods connect and macOS moves both defaults to them.
        mac.outputs.append("airpods"); mac.inputs.append("airpods-mic")
        mac.current = [.output: "airpods", .input: "airpods-mic"]
        let commands = mac.send(.systemChanged, to: &engine)
        #expect(commands == [.init(.input, "dji")])
        #expect(mac.current == [.output: "airpods", .input: "dji"])
    }

    @Test func aPickStaysUntilAHigherRankedDeviceConnects() {
        var mac = Mac(outputs: ["speakers", "display"], order: [.output: ["airpods", "speakers", "display"], .input: ["dji"]])
        mac.inputs = ["dji"]
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        #expect(mac.send(.userSelected(.output, "display"), to: &engine) == [.init(.output, "display")])
        #expect(engine.pick[.output] == "display")

        // Something unrelated changes: the pick holds.
        mac.inputs.append("mac-mic")
        #expect(mac.send(.systemChanged, to: &engine) == [])

        // A device ranked above the pick connects: the list wins again.
        mac.outputs.append("airpods")
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.output, "airpods")])
        #expect(engine.pick[.output] == nil)
    }

    @Test func aPickEndsWhenItDisconnects() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.send(.userSelected(.input, "mac-mic"), to: &engine)
        mac.inputs.removeAll { $0 == "mac-mic" }
        mac.current[.input] = "airpods-mic" // macOS falls back on its own
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
    }

    @Test func pickingTheTopDeviceIsNotAPick() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.send(.userSelected(.output, "speakers"), to: &engine)
        mac.send(.userSelected(.output, "airpods"), to: &engine)
        #expect(engine.pick[.output] == nil)
    }

    @Test func outputIsSwitchedBackOnceThenLeft() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.send(.userSelected(.output, "speakers"), to: &engine)

        // AirPods in the ears take the output on their own.
        mac.now += 60; mac.current[.output] = "airpods"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.output, "speakers")])

        // They take it again a few seconds later: leave it.
        mac.now += 4; mac.current[.output] = "airpods"
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(engine.takeover[.output] == "airpods")

        // Still left alone on later, unrelated changes.
        mac.now += 100
        #expect(mac.send(.systemChanged, to: &engine) == [])

        // Picking again starts over.
        #expect(mac.send(.userSelected(.output, "speakers"), to: &engine) == [.init(.output, "speakers")])
        #expect(engine.takeover[.output] == nil)
    }

    @Test func microphoneIsAlwaysTakenBack() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        for _ in 0..<5 {
            mac.now += 4.4 // AirPods retry at this pace
            mac.current[.input] = "airpods-mic"
            #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
        }
        #expect(engine.takeover[.input] == nil)
    }

    @Test func aFastMicrophoneFightPausesThenResumes() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.now += 10; mac.current[.input] = "mac-mic"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
        // Another app takes it back within a second, three times in a row.
        for _ in 0..<2 {
            mac.now += 0.2; mac.current[.input] = "mac-mic"
            #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
        }
        mac.now += 0.2; mac.current[.input] = "mac-mic"
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(engine.takeover[.input] == "mac-mic")
        #expect(engine.microphonePauseEndsAt == mac.now + SwitchEngine.microphonePause)

        mac.now += SwitchEngine.microphonePause
        #expect(mac.send(.microphonePauseEnded, to: &engine) == [.init(.input, "dji")])
        #expect(engine.takeover[.input] == nil)
    }

    @Test func aPickInControlCenterIsKept() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.now += 5; mac.userPicking = true; mac.current[.input] = "mac-mic"
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(engine.pick[.input] == "mac-mic")
    }

    @Test func aHiddenDeviceIsNeverChosen() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        mac.hidden = ["airpods", "dji"]
        var engine = SwitchEngine(auto: true)
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "airpods-mic")])
        #expect(mac.current[.output] == "speakers")
    }

    @Test func hidingTheDeviceInUseMovesToTheNext() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.hidden = ["dji"]
        #expect(mac.send(.prioritiesChanged(.input), to: &engine) == [.init(.input, "airpods-mic")])
    }

    @Test func reRankingAppliesTheNewTop() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.order[.output] = ["speakers", "airpods"]
        #expect(mac.send(.prioritiesChanged(.output), to: &engine) == [.init(.output, "speakers")])
    }

    @Test func turningAutoOnGoesBackToTheList() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        var engine = SwitchEngine(auto: false)
        mac.send(.systemChanged, to: &engine)
        let commands = mac.send(.autoChanged(true), to: &engine)
        #expect(commands == [.init(.output, "airpods"), .init(.input, "dji")])
    }

    @Test func autoOffHoldsTheMicrophoneButLetsAConnectedDeviceTakeTheOutput() {
        var mac = Mac(outputs: ["speakers"], inputs: ["dji", "mac-mic"])
        var engine = SwitchEngine(auto: false)
        mac.send(.systemChanged, to: &engine)

        mac.outputs.append("airpods"); mac.inputs.append("airpods-mic")
        mac.current = [.output: "airpods", .input: "airpods-mic"]
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
        #expect(engine.held[.output] == "airpods")
    }

    @Test func autoOffSwitchesBackWhenMacOSMovesIt() {
        var mac = Mac()
        var engine = SwitchEngine(auto: false)
        mac.send(.systemChanged, to: &engine)
        mac.now += 60; mac.current[.output] = "airpods"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.output, "speakers")])
    }

    @Test func autoOffFallsToTheListWhenTheHeldDeviceLeaves() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        var engine = SwitchEngine(auto: false)
        mac.send(.systemChanged, to: &engine)
        mac.inputs.removeAll { $0 == "mac-mic" }
        mac.current[.input] = "airpods-mic"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
        #expect(engine.held[.input] == "dji")
    }

    @Test func hidingAnUnrelatedDeviceKeepsThePick() {
        var mac = Mac(outputs: ["airpods", "speakers", "display"], order: [.output: ["airpods", "speakers", "display"], .input: ["dji"]])
        mac.inputs = ["dji"]; mac.current[.output] = "airpods"
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.send(.userSelected(.output, "speakers"), to: &engine)

        mac.hidden = ["display"]
        #expect(mac.send(.prioritiesChanged(.output), to: &engine) == [])
        #expect(engine.pick[.output] == "speakers")

        // Hiding the pick itself falls back to the list.
        mac.hidden = ["display", "speakers"]
        #expect(mac.send(.prioritiesChanged(.output), to: &engine) == [.init(.output, "airpods")])
        #expect(engine.pick[.output] == nil)
    }

    @Test func aNewTopOfTheListEndsThePick() {
        var mac = Mac(outputs: ["airpods", "speakers", "display"], order: [.output: ["airpods", "speakers", "display"], .input: ["dji"]])
        mac.inputs = ["dji"]; mac.current[.output] = "airpods"
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.send(.userSelected(.output, "speakers"), to: &engine)

        // Re-ranking below the top leaves the pick alone.
        mac.order[.output] = ["airpods", "display", "speakers"]
        #expect(mac.send(.prioritiesChanged(.output), to: &engine) == [])

        mac.order[.output] = ["display", "airpods", "speakers"]
        #expect(mac.send(.prioritiesChanged(.output), to: &engine) == [.init(.output, "display")])
        #expect(engine.pick[.output] == nil)
    }

    @Test func autoOffHidingTheHeldDeviceFallsToTheList() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        var engine = SwitchEngine(auto: false)
        mac.send(.systemChanged, to: &engine)
        mac.hidden = ["mac-mic"]
        #expect(mac.send(.prioritiesChanged(.input), to: &engine) == [.init(.input, "dji")])
        #expect(engine.held[.input] == "dji")
    }

    @Test func aDeviceTheUserAskedForIsNotSwitchedAwayFromWhenItArrives() {
        var mac = Mac(outputs: ["sony"], order: [.output: ["sony", "airpods"], .input: ["dji"]])
        mac.inputs = ["dji"]; mac.current[.output] = "sony"
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)

        // The AirPods connect because the user clicked their row, and macOS
        // moves the output to them. The pick is applied before the report.
        mac.outputs.append("airpods"); mac.current[.output] = "airpods"
        #expect(mac.send(.userSelected(.output, "airpods"), to: &engine) == [])
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(mac.current[.output] == "airpods")
    }

    /// The app hears about its own switch up to 100 ms later. A device that
    /// takes the role back inside that time must still count as a retake.
    @Test func aRetakeBeforeTheNextReportStillCountsAsAFight() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)

        // The microphone: three fast retakes, each seen with no report in between.
        var paused = false
        for _ in 0..<5 where !paused {
            mac.now += 0.2; mac.current[.input] = "airpods-mic"
            paused = engine.handle(.systemChanged, mac.input) == []
        }
        #expect(paused)
        #expect(engine.takeover[.input] == "airpods-mic")
        #expect(engine.microphonePauseEndsAt != nil)

        // The output: switched back once, then left.
        mac.now += 60; mac.current[.output] = "airpods"; mac.order[.output] = ["speakers", "airpods"]
        mac.current[.input] = "dji"
        var fresh = SwitchEngine(auto: true)
        _ = fresh.handle(.systemChanged, Mac(order: mac.order).input)
        #expect(fresh.handle(.systemChanged, mac.input) == [.init(.output, "speakers")])
        mac.now += 5
        #expect(fresh.handle(.systemChanged, mac.input) == [])
        #expect(fresh.takeover[.output] == "airpods")
    }

    @Test func aTakeoverEndsOnceTheOutputLeavesThatDevice() {
        var mac = Mac(outputs: ["airpods", "speakers", "display"], order: [.output: ["speakers", "airpods", "display"], .input: ["dji"]])
        mac.inputs = ["dji"]
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.now += 60; mac.current[.output] = "airpods"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.output, "speakers")])
        mac.now += 5; mac.current[.output] = "airpods"
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(engine.takeover[.output] == "airpods")

        // The output moves on, is put back, and much later the AirPods take it again.
        mac.now += 60; mac.current[.output] = "display"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.output, "speakers")])
        #expect(engine.takeover[.output] == nil)
        mac.now += 600; mac.current[.output] = "airpods"
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.output, "speakers")])
    }

    /// A wireless microphone that is switched off stays the Mac's default: its
    /// receiver is still plugged in. To the engine it has left, but macOS has
    /// not moved the input.
    @Test func aDeviceThatLeavesWhileStillTheDefaultIsMovedOffAndBack() {
        var mac = Mac()
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)

        mac.inputs.removeAll { $0 == "dji" }
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "airpods-mic")])
        mac.inputs.append("dji")
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
    }

    @Test func autoOffADeviceThatLeavesWhileStillTheDefaultFallsToTheList() {
        var mac = Mac(current: [.output: "speakers", .input: "mac-mic"])
        var engine = SwitchEngine(auto: false)
        mac.send(.systemChanged, to: &engine)

        mac.inputs.removeAll { $0 == "mac-mic" }
        #expect(mac.send(.systemChanged, to: &engine) == [.init(.input, "dji")])
        // Back again, it is not returned to by the engine; the app asks for that itself.
        mac.inputs.append("mac-mic")
        #expect(mac.send(.systemChanged, to: &engine) == [])
        #expect(mac.send(.userSelected(.input, "mac-mic"), to: &engine) == [.init(.input, "mac-mic")])
        #expect(engine.held[.input] == "mac-mic")
    }

    @Test func theOnlyDeviceLeavingWhileStillTheDefaultChangesNothing() {
        var mac = Mac(inputs: ["dji"], order: [.output: ["airpods", "speakers"], .input: ["dji"]])
        var engine = SwitchEngine(auto: true)
        mac.send(.systemChanged, to: &engine)
        mac.inputs = []
        #expect(mac.send(.systemChanged, to: &engine) == [])
    }
}
