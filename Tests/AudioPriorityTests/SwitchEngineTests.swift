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
}
