import SwiftUI

struct AppListView: View {
    @AppStorage("ignoredApps") private var ignoredAppsData: Data = Data()
    @State private var newAppID = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Excluded Apps").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding()

            List {
                ForEach(getIgnoredApps(), id: \.self) { id in
                    HStack {
                        Text(id).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) { removeApp(id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                TextField("com.apple.Safari", text: $newAppID)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addApp() }.disabled(newAppID.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }

    private func getIgnoredApps() -> [String] {
        return (try? JSONDecoder().decode([String].self, from: ignoredAppsData)) ?? []
    }

    private func addApp() {
        var apps = getIgnoredApps()
        if !apps.contains(newAppID) {
            apps.append(newAppID)
            save(apps)
            newAppID = ""
        }
    }

    private func removeApp(_ id: String) {
        var apps = getIgnoredApps()
        apps.removeAll { $0 == id }
        save(apps)
    }

    private func save(_ apps: [String]) {
        if let data = try? JSONEncoder().encode(apps) {
            ignoredAppsData = data
        }
    }
}
