import AudioPriorityCore
import Observation
import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Keeps the login item in line with the user's wish, which defaults to on.
/// From DayNight, by the same author.
@Observable
@MainActor
final class LaunchAtLogin {
    enum Issue: Equatable {
        case needsApproval
        case notInApplications
        case failed(String)

        var message: String {
            switch self {
            case .needsApproval: "Needs your approval."
            case .notInApplications: "Move Audio Priority to Applications first."
            case .failed(let reason): reason
            }
        }
    }

    private(set) var isEnabled: Bool
    private(set) var issue: Issue?

    @ObservationIgnored private let store: PriorityStore
    @ObservationIgnored private let isDryRun: Bool
    @ObservationIgnored private let service: any LoginItemService

    init(store: PriorityStore, isDryRun: Bool, service: any LoginItemService = SMAppService.mainApp) {
        self.store = store
        self.isDryRun = isDryRun
        self.service = service
        isEnabled = store.launchAtLogin
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        store.launchAtLogin = enabled
        sync()
    }

    /// Registers or unregisters to match the stored wish. A dry run leaves the login item alone.
    func sync() {
        guard !isDryRun else { return }
        let registered = service.status == .enabled || service.status == .requiresApproval
        do {
            if isEnabled, !registered {
                try service.register()
            } else if !isEnabled, registered {
                try service.unregister()
            }
            refresh()
        } catch {
            // The status often explains the failure better than the error does.
            refresh()
            guard issue != .notInApplications else { return }
            issue = .failed(isEnabled ? "Couldn’t turn on: \(error.localizedDescription)"
                                      : "Couldn’t turn off: \(error.localizedDescription)")
        }
    }

    func refresh() {
        guard isEnabled else {
            issue = nil
            return
        }
        switch service.status {
        case .enabled: issue = nil
        case .requiresApproval: issue = .needsApproval
        case .notFound: issue = .notInApplications
        default: issue = .failed("Not added to Login Items. Turn this off and on again.")
        }
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
