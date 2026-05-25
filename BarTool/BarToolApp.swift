import SwiftUI
import AppKit
import ServiceManagement

@main
struct BarToolApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            Image("BarMenuIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ProcessUsage {
    let cpu: Double
    let memoryMB: Int
}

struct RunningApp: Identifiable {
    let id = UUID()
    let app: NSRunningApplication
    let name: String
    let bundleID: String
    let icon: NSImage?
    var cpu: Double = 0
    var memoryMB: Int = 0
}

enum SortType {
    case name
    case cpu
    case memory
}

final class AppMonitor: ObservableObject {
    @Published var apps: [RunningApp] = []
    @Published var searchText = ""

    @Published var showSystemProcesses = false
    @Published var showAppleApps = false
    @Published var showPerformance = false
    @Published var launchAtLogin = false

    @Published var sortType: SortType = .name
    @Published var ascending = true

    private var timer: Timer?

    init() {
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.refresh()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        let usageMap = showPerformance ? getAllProcessUsage() : [:]
        let runningApps = NSWorkspace.shared.runningApplications
        let currentPID = ProcessInfo.processInfo.processIdentifier

        var list: [RunningApp] = []

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else {
                continue
            }

            if app.processIdentifier == currentPID {
                continue
            }

            let name = app.localizedName ?? "Unknown"

            if !showSystemProcesses {
                if isHiddenProcess(name: name, bundleID: bundleID) {
                    continue
                }

                if app.activationPolicy == .prohibited {
                    continue
                }
            }

            if !showAppleApps {
                if bundleID.hasPrefix("com.apple.") {
                    continue
                }
            }

            if !searchText.isEmpty {
                let keyword = searchText.lowercased()

                if !name.lowercased().contains(keyword)
                    && !bundleID.lowercased().contains(keyword) {
                    continue
                }
            }

            let usage = usageMap[app.processIdentifier]

            let item = RunningApp(
                app: app,
                name: name,
                bundleID: bundleID,
                icon: app.icon,
                cpu: usage?.cpu ?? 0,
                memoryMB: usage?.memoryMB ?? 0
            )

            list.append(item)
        }

        DispatchQueue.main.async {
            self.apps = self.sortApps(list)
        }
    }

    func getAllProcessUsage() -> [pid_t: ProcessUsage] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = [
            "ax",
            "-o",
            "pid=,%cpu=,rss="
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            guard let output = String(data: data, encoding: .utf8) else {
                return [:]
            }

            var result: [pid_t: ProcessUsage] = [:]

            for line in output.split(separator: "\n") {
                let parts = line.split(whereSeparator: { ch in
                    ch == " " || ch == "\t"
                })

                if parts.count >= 3,
                   let pidInt = Int32(String(parts[0])),
                   let cpu = Double(String(parts[1])),
                   let rssKB = Int(String(parts[2])) {

                    let pid = pid_t(pidInt)
                    result[pid] = ProcessUsage(
                        cpu: cpu,
                        memoryMB: rssKB / 1024
                    )
                }
            }

            return result
        } catch {
            return [:]
        }
    }

    func isHiddenProcess(name: String, bundleID: String) -> Bool {
        let n = name.lowercased()
        let b = bundleID.lowercased()

        let keywords = [
            "helper",
            "renderer",
            "gpu",
            "plugin",
            "utility",
            "agent",
            "service",
            "web content",
            "network process",
            "crashpad",
            "monitor",
            "assistant",
            "loginwindow",
            "windowmanager",
            "storeuid",
            "softwareupdate",
            "keychain",
            "systemuiserver",
            "controlcenter",
            "notificationcenter",
            "spotlight",
            "dock"
        ]

        return keywords.contains {
            n.contains($0) || b.contains($0)
        }
    }

    func sortApps(_ list: [RunningApp]) -> [RunningApp] {
        switch sortType {
        case .name:
            return list.sorted {
                ascending
                ? $0.name.lowercased() < $1.name.lowercased()
                : $0.name.lowercased() > $1.name.lowercased()
            }

        case .cpu:
            return list.sorted {
                ascending
                ? $0.cpu < $1.cpu
                : $0.cpu > $1.cpu
            }

        case .memory:
            return list.sorted {
                ascending
                ? $0.memoryMB < $1.memoryMB
                : $0.memoryMB > $1.memoryMB
            }
        }
    }

    func toggleSort(_ type: SortType) {
        if sortType == type {
            ascending.toggle()
        } else {
            sortType = type
            ascending = false
        }

        apps = sortApps(apps)
    }

    func quitApp(_ app: NSRunningApplication) {
        app.terminate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !app.isTerminated {
                app.forceTerminate()
            }

            self.refresh()
        }
    }

    func activateApp(_ app: NSRunningApplication) {
        if let bundleID = app.bundleIdentifier {
            let script = """
            tell application id "\(bundleID)"
                activate
                reopen
            end tell
            """

            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            app.unhide()
            app.activate(options: [
                .activateAllWindows,
                .activateIgnoringOtherApps
            ])
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct MenuView: View {
    @StateObject private var monitor = AppMonitor()

    var body: some View {
        VStack(spacing: 8) {
            TextField(
                "Search app name or Bundle ID...",
                text: $monitor.searchText
            )
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .onChange(of: monitor.searchText) {
                monitor.refresh()
            }

            HStack(spacing: 14) {
                Toggle("System", isOn: $monitor.showSystemProcesses)
                    .toggleStyle(.checkbox)
                    .onChange(of: monitor.showSystemProcesses) {
                        monitor.refresh()
                    }

                Toggle("Apple", isOn: $monitor.showAppleApps)
                    .toggleStyle(.checkbox)
                    .onChange(of: monitor.showAppleApps) {
                        monitor.refresh()
                    }

                Toggle("CPU", isOn: $monitor.showPerformance)
                    .toggleStyle(.checkbox)
                    .onChange(of: monitor.showPerformance) {
                        monitor.refresh()
                    }

                Toggle(
                    "Launch",
                    isOn: Binding(
                        get: {
                            monitor.launchAtLogin
                        },
                        set: {
                            monitor.setLaunchAtLogin($0)
                        }
                    )
                )
                .toggleStyle(.checkbox)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 12)

            Divider()

            HStack {
                Button {
                    monitor.toggleSort(.name)
                } label: {
                    Text(
                        monitor.sortType == .name
                        ? "Name \(monitor.ascending ? "↑" : "↓")"
                        : "Name"
                    )
                    .font(.headline)
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .frame(width: 180, alignment: .leading)

                Spacer()

                if monitor.showPerformance {
                    Button {
                        monitor.toggleSort(.cpu)
                    } label: {
                        Text(
                            monitor.sortType == .cpu
                            ? "CPU \(monitor.ascending ? "↑" : "↓")"
                            : "CPU"
                        )
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 70)

                    Button {
                        monitor.toggleSort(.memory)
                    } label: {
                        Text(
                            monitor.sortType == .memory
                            ? "MEM \(monitor.ascending ? "↑" : "↓")"
                            : "MEM"
                        )
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 80)
                }

                Spacer()
                    .frame(width: 70)
            }
            .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(monitor.apps) { item in
                        HStack {
                            if let icon = item.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)

                                Text(item.bundleID)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(width: 180, alignment: .leading)

                            Spacer()

                            if monitor.showPerformance {
                                Text(String(format: "%.1f%%", item.cpu))
                                    .frame(width: 70)

                                Text("\(item.memoryMB) MB")
                                    .frame(width: 80)
                            }

                            Button("Quit") {
                                monitor.quitApp(item.app)
                            }
                            .buttonStyle(.bordered)
                            .frame(width: 70)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                        )
                        .onTapGesture(count: 2) {
                            monitor.activateApp(item.app)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()

            HStack {
                Spacer()

                Text("Running \(monitor.apps.count)")
                    .foregroundColor(.gray)
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
            }
        }
        .frame(
            minWidth: 560,
            idealWidth: 600,
            minHeight: 420,
            idealHeight: 540
        )
    }
}
