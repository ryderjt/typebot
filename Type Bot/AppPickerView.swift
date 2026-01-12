import SwiftUI
import AppKit

struct AppPickerView: View {
    var onPick: (NSRunningApplication) -> Void
    var onCancel: () -> Void
    @State private var runningApps: [NSRunningApplication] = []
    @State private var selectedApp: NSRunningApplication?
    
    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.1, green: 0.14, blue: 0.22), Color(red: 0.05, green: 0.08, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            AngularGradient(
                colors: [
                    Color(red: 0.32, green: 0.72, blue: 1.0).opacity(0.3),
                    Color(red: 0.62, green: 0.44, blue: 1.0).opacity(0.18),
                    Color.clear
                ],
                center: .center
            )
            .blur(radius: 70)
        )
    }
    
    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "sparkles")
                            .foregroundColor(.white)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose a target window")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("The app will stay focused while Type Bot types")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(runningApps, id: \.processIdentifier) { app in
                            Button {
                                selectedApp = app
                            } label: {
                                HStack(spacing: 12) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .cornerRadius(8)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.localizedName ?? "Untitled App")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        Text(app.bundleIdentifier ?? "")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    if selectedApp?.processIdentifier == app.processIdentifier {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.32, green: 0.72, blue: 1.0))
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(selectedApp?.processIdentifier == app.processIdentifier ? 0.12 : 0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 320)
                
                HStack {
                    Button {
                        refreshApps()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Button {
                        if let selectedApp {
                            onPick(selectedApp)
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.32, green: 0.72, blue: 1.0), Color(red: 0.24, green: 0.9, blue: 0.84)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .foregroundColor(.black.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedApp == nil)
                    .opacity(selectedApp == nil ? 0.6 : 1)
                }
            }
            .padding(20)
            .frame(width: 430)
        }
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
