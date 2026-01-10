import SwiftUI
import AppKit

struct AppPickerView: View {
    var onPick: (NSRunningApplication) -> Void
    var onCancel: () -> Void
    @State private var runningApps: [NSRunningApplication] = []
    @State private var selectedApp: NSRunningApplication?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Choose a target window")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
            }
            
            List(runningApps, id: \.bundleIdentifier) { app in
                Button {
                    selectedApp = app
                } label: {
                    HStack(spacing: 12) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                                .cornerRadius(6)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.localizedName ?? "Untitled App")
                                .font(.system(size: 13, weight: .medium))
                            Text(app.bundleIdentifier ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedApp?.bundleIdentifier == app.bundleIdentifier {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 320)
            
            HStack {
                Button("Refresh") {
                    refreshApps()
                }
                Spacer()
                Button("Start") {
                    if let selectedApp {
                        onPick(selectedApp)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.2, green: 0.55, blue: 0.95))
                .disabled(selectedApp == nil)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            refreshApps()
        }
    }
    
    private func refreshApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
