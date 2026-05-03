import SwiftUI
import AppKit

struct AppManagementView: View {
    @AppStorage("perAppTints") private var perAppTintsData: Data = Data()
    @AppStorage("excludedApps") private var excludedAppsData: Data = Data()
    
    @State private var runningApps: [NSRunningApplication] = []
    @State private var searchText: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Rules & Exclusions")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search running apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            List {
                Section("Currently Running Apps") {
                    let filteredApps = runningApps.filter {
                        searchText.isEmpty ? true : ($0.localizedName ?? "").localizedCaseInsensitiveContains(searchText)
                    }
                    
                    ForEach(filteredApps, id: \.bundleIdentifier) { app in
                        if let name = app.localizedName, let bid = app.bundleIdentifier {
                            AppRowView(
                                name: name,
                                icon: app.icon,
                                bid: bid,
                                isExcluded: getExcluded().contains(bid),
                                customColor: getCustomTints()[bid],
                                onExclude: { addExclusion(bid) },
                                onSetTint: { color in setCustomTint(bid, color: color) }
                            )
                        }
                    }
                }

                Section("Custom App Tints") {
                    let tints = getCustomTints()
                    if tints.isEmpty {
                        Text("No custom tints set").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(tints.sorted(by: { $0.key < $1.key }), id: \.key) { bid, colorHex in
                        HStack {
                            Circle().fill(Color(hex: colorHex) ?? .clear).frame(width: 10, height: 10)
                            Text(bid).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Button("Remove") { removeCustomTint(bid) }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }

                Section("Exclusions (No Tint)") {
                    let excludedList = getExcluded()
                    if excludedList.isEmpty {
                        Text("No apps excluded").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(excludedList, id: \.self) { bid in
                        HStack {
                            Text(bid).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Button("Remove") { removeExclusion(bid) }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
            }
            .listStyle(.inset)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
        .liquidGlassStyle()
        .onAppear(perform: updateRunningApps)
    }

    private func updateRunningApps() {
        let currentBid = Bundle.main.bundleIdentifier
        self.runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != currentBid }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func getExcluded() -> [String] {
        (try? JSONDecoder().decode([String].self, from: excludedAppsData)) ?? []
    }
    
    private func addExclusion(_ bid: String) {
        removeCustomTint(bid)
        var list = getExcluded()
        if !list.contains(bid) {
            list.append(bid)
            excludedAppsData = (try? JSONEncoder().encode(list)) ?? Data()
        }
    }
    
    private func removeExclusion(_ bid: String) {
        var list = getExcluded()
        list.removeAll { $0 == bid }
        excludedAppsData = (try? JSONEncoder().encode(list)) ?? Data()
    }

    private func getCustomTints() -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: perAppTintsData)) ?? [:]
    }
    
    private func setCustomTint(_ bid: String, color: Color) {
        removeExclusion(bid)
        var tints = getCustomTints()
        tints[bid] = color.toHex()
        perAppTintsData = (try? JSONEncoder().encode(tints)) ?? Data()
    }
    
    private func removeCustomTint(_ bid: String) {
        var tints = getCustomTints()
        tints.removeValue(forKey: bid)
        perAppTintsData = (try? JSONEncoder().encode(tints)) ?? Data()
    }
}

struct AppRowView: View {
    let name: String
    let icon: NSImage?
    let bid: String
    let isExcluded: Bool
    let customColor: String?
    
    var onExclude: () -> Void
    var onSetTint: (Color) -> Void
    
    @State private var selectedColor: Color = .blue

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading) {
                Text(name).font(.system(size: 13, weight: .medium))
                Text(bid).font(.system(size: 10)).foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .onChange(of: selectedColor) { oldValue, newValue in
                        onSetTint(newValue)
                    }
                
                Button(customColor != nil ? "Tint Set" : "Tint") {
                    onSetTint(selectedColor)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.blue)
                
                Button(isExcluded ? "Excluded" : "Exclude") {
                    onExclude()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .disabled(isExcluded)
            }
        }
        .padding(.vertical, 4)
    }
}
