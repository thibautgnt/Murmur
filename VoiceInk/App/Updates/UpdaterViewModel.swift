import AppKit
import Foundation
import os
import SwiftUI

/// Checks the GitHub releases of the Murmur repository. The build commit is
/// stamped into Info.plist by `make install` and `make share`.
@MainActor
final class UpdaterViewModel: ObservableObject {
    struct AvailableUpdate: Equatable {
        let versionIdentifier: String
        let displayVersion: String
        let downloadURL: URL
    }

    private enum DefaultsKey {
        // Keep the existing persisted key string so current user preferences migrate automatically.
        static let automaticUpdateChecks = "VoiceInkChecksForUpdatesOnLaunch"
        static let lastUpdateCheck = "MurmurLastUpdateCheck"
        static let postponedUpdate = "MurmurPostponedUpdate"
        static let postponedUntil = "MurmurPostponedUntil"
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let name: String?
        let assets: [Asset]
    }

    private struct Comparison: Decodable {
        let status: String
    }

    private enum CheckResult {
        case available(AvailableUpdate)
        case upToDate
        case unavailable(String)
    }

    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "Updater")
    private static let repository = "thibautgnt/Murmur"
    private static let assetName = "Murmur.zip"
    private static let checkInterval: TimeInterval = 6 * 60 * 60
    private static let postponeInterval: TimeInterval = 24 * 60 * 60

    @Published var canCheckForUpdates = true
    @Published private(set) var checksForUpdatesWhenDashboardAppears: Bool
    @Published private(set) var availableUpdate: AvailableUpdate?

    private let defaults = UserDefaults.standard
    private let buildCommit = Bundle.main.object(forInfoDictionaryKey: "MurmurCommit") as? String
    private var timer: Timer?

    init() {
        checksForUpdatesWhenDashboardAppears =
            (defaults.object(forKey: DefaultsKey.automaticUpdateChecks) as? Bool) ?? true

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            self?.checkForUpdatesIfDue()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdatesIfDue() }
        }
    }

    func setChecksForUpdatesWhenDashboardAppears(_ value: Bool) {
        guard checksForUpdatesWhenDashboardAppears != value else { return }

        checksForUpdatesWhenDashboardAppears = value
        defaults.set(value, forKey: DefaultsKey.automaticUpdateChecks)

        if value {
            defaults.removeObject(forKey: DefaultsKey.lastUpdateCheck)
            checkForUpdatesIfDue()
        } else {
            availableUpdate = nil
        }
    }

    func checkForUpdatesIfDue() {
        guard checksForUpdatesWhenDashboardAppears, canCheckForUpdates, buildCommit != nil else { return }

        if let lastCheck = defaults.object(forKey: DefaultsKey.lastUpdateCheck) as? Date {
            let elapsed = Date().timeIntervalSince(lastCheck)
            guard elapsed < 0 || elapsed >= Self.checkInterval else { return }
        }

        Task { await runCheck(userInitiated: false) }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        Task { await runCheck(userInitiated: true) }
    }

    private func runCheck(userInitiated: Bool) async {
        canCheckForUpdates = false
        let result = await fetchUpdate()
        canCheckForUpdates = true
        defaults.set(Date(), forKey: DefaultsKey.lastUpdateCheck)
        Self.logger.notice("Update check build=\(self.buildCommit ?? "none", privacy: .public) result=\(String(describing: result), privacy: .public)")

        switch result {
        case .available(let update):
            availableUpdate = update
            if userInitiated || !isPostponed(update) {
                await offer(update)
            }
        case .upToDate:
            availableUpdate = nil
            if userInitiated {
                showAlert(
                    title: String(localized: "Murmur is up to date"),
                    message: String(localized: "You have the latest version.")
                )
            }
        case .unavailable(let reason):
            if userInitiated {
                showAlert(title: String(localized: "Unable to check for updates"), message: reason)
            }
        }
    }

    private func fetchUpdate() async -> CheckResult {
        guard let buildCommit else {
            return .unavailable(String(localized: "This development build cannot check for updates."))
        }

        do {
            let release: Release = try await fetchJSON("releases/latest")
            guard let asset = release.assets.first(where: { $0.name == Self.assetName }) else {
                return .upToDate
            }
            // "ahead" means the release contains commits this build lacks; a local
            // build with unreleased commits compares as "identical", "behind" or "diverged".
            let comparison: Comparison = try await fetchJSON("compare/\(buildCommit)...\(release.tag_name)")
            guard comparison.status == "ahead" else { return .upToDate }

            return .available(
                AvailableUpdate(
                    versionIdentifier: release.tag_name,
                    displayVersion: release.name ?? release.tag_name,
                    downloadURL: asset.browser_download_url
                ))
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    private func fetchJSON<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/\(path)")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func offer(_ update: AvailableUpdate) async {
        AppPresentationPolicy.activateForUserFacingWindow()
        defer { AppPresentationPolicy.restoreAccessoryIfNeededAfterUserFacingWindowClosed() }
        let alert = NSAlert()
        alert.messageText = String(localized: "A new version of Murmur is available")
        alert.informativeText = String(
            format: String(localized: "%@ is available. Update now? Murmur will restart."),
            update.displayVersion
        )
        alert.addButton(withTitle: String(localized: "Update Now"))
        alert.addButton(withTitle: String(localized: "Later"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            defaults.set(update.versionIdentifier, forKey: DefaultsKey.postponedUpdate)
            defaults.set(Date().addingTimeInterval(Self.postponeInterval), forKey: DefaultsKey.postponedUntil)
            return
        }

        canCheckForUpdates = false
        do {
            try await install(update)
        } catch {
            canCheckForUpdates = true
            showAlert(title: String(localized: "The update could not be installed"), message: error.localizedDescription)
        }
    }

    private func isPostponed(_ update: AvailableUpdate) -> Bool {
        guard defaults.string(forKey: DefaultsKey.postponedUpdate) == update.versionIdentifier,
            let until = defaults.object(forKey: DefaultsKey.postponedUntil) as? Date
        else { return false }
        return Date() < until
    }

    private func install(_ update: AvailableUpdate) async throws {
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MurmurUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let (download, _) = try await URLSession.shared.download(from: update.downloadURL)
        let archive = workDirectory.appendingPathComponent(Self.assetName)
        try FileManager.default.moveItem(at: download, to: archive)

        try await run("/usr/bin/ditto", ["-x", "-k", archive.path, workDirectory.path])
        let newApp = workDirectory.appendingPathComponent("Murmur.app")
        try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

        // The running bundle cannot be replaced in place: a detached shell waits for
        // this process to exit, swaps the bundle (restoring it on failure) and relaunches.
        let script = """
            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
            rm -rf "$2.old"
            if mv "$2" "$2.old" && /usr/bin/ditto "$3" "$2"; then rm -rf "$2.old"; else rm -rf "$2"; mv "$2.old" "$2"; fi
            open "$2"
            rm -rf "$4"
            """
        let swap = Process()
        swap.executableURL = URL(fileURLWithPath: "/bin/sh")
        swap.arguments = [
            "-c", script, "sh",
            String(ProcessInfo.processInfo.processIdentifier),
            Bundle.main.bundlePath,
            newApp.path,
            workDirectory.path,
        ]
        try swap.run()
        NSApp.terminate(nil)
    }

    private func run(_ executable: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadCorruptFile))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func showAlert(title: String, message: String) {
        AppPresentationPolicy.activateForUserFacingWindow()
        defer { AppPresentationPolicy.restoreAccessoryIfNeededAfterUserFacingWindowClosed() }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        Button("Check for Updates…", action: updaterViewModel.checkForUpdates)
            .disabled(!updaterViewModel.canCheckForUpdates)
    }
}
