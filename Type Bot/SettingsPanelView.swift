import SwiftUI
import AppKit
import ApplicationServices

struct SettingsPanelView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: TypeBotSettings
    @State private var hasAccessibility = AXIsProcessTrusted()
    
    var body: some View {
        let panelFill = settings.isDarkMode ? Color.black.opacity(0.72) : Color.white.opacity(0.92)
        let panelStroke = settings.isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
        let titleColor = settings.isDarkMode ? Color.white : Color.black
        let secondary = settings.isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
        
        VStack(spacing: 18) {
            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(titleColor)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(settings.isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            
            ScrollView {
                VStack(spacing: 16) {
                    settingsSection(title: "Appearance") {
                        Toggle(isOn: $settings.isDarkMode) {
                            Label("Dark Mode", systemImage: "moon.fill")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    
                    settingsSection(title: "Typing") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Text("\(Int(settings.typingSpeed)) chars/sec")
                                    .foregroundColor(secondary)
                            }
                            Slider(value: $settings.typingSpeed, in: 20...320, step: 10)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Activation Delay")
                                Spacer()
                                Text(String(format: "%.1fs", settings.activationDelay))
                                    .foregroundColor(secondary)
                            }
                            Slider(value: $settings.activationDelay, in: 0.2...2.0, step: 0.1)
                        }
                        Toggle(isOn: $settings.useBoldShortcut) {
                            Text("Use bold shortcut")
                        }
                        Toggle(isOn: $settings.useItalicShortcut) {
                            Text("Use italic shortcut")
                        }
                        Toggle(isOn: $settings.useUnderlineShortcut) {
                            Text("Use underline shortcut")
                        }
                        Toggle(isOn: $settings.useStrikethroughShortcut) {
                            Text("Use strikethrough shortcut")
                        }
                    }
                    
                    settingsSection(title: "Keybinds") {
                        keybindRow(title: "Start", binding: $settings.startKeyBinding)
                        keybindRow(title: "Pause", binding: $settings.pauseKeyBinding)
                        keybindRow(title: "Stop", binding: $settings.stopKeyBinding)
                    }
                    
                    settingsSection(title: "Accessibility") {
                        Text("Type Bot uses Accessibility permissions to send keystrokes into other apps.")
                            .font(.system(size: 12))
                            .foregroundColor(secondary)
                        Button("Open Accessibility Settings") {
                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                            if let url {
                                NSWorkspace.shared.open(url)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                hasAccessibility = AXIsProcessTrusted()
                            }
                        }
                        .buttonStyle(.bordered)
                        HStack(spacing: 8) {
                            Image(systemName: hasAccessibility ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(hasAccessibility ? .green : .orange)
                            Text(hasAccessibility ? "Accessibility enabled" : "Accessibility not granted")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(secondary)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(panelStroke, lineWidth: 1)
                )
        )
        .foregroundColor(settings.isDarkMode ? .white : .black)
        .onAppear {
            hasAccessibility = AXIsProcessTrusted()
        }
    }
    
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(settings.isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settings.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
            )
        }
    }
    
    private func keybindRow(title: String, binding: Binding<KeyBinding>) -> some View {
        HStack {
            Text(title)
            Spacer()
            KeyCaptureField(binding: binding, isDarkMode: settings.isDarkMode)
                .frame(width: 160)
        }
    }
}

struct KeyCaptureField: NSViewRepresentable {
    @Binding var binding: KeyBinding
    let isDarkMode: Bool
    
    func makeNSView(context: Context) -> KeyCaptureTextField {
        let field = KeyCaptureTextField()
        field.isEditable = false
        field.isBordered = true
        field.drawsBackground = true
        field.backgroundColor = isDarkMode ? NSColor.black.withAlphaComponent(0.25) : NSColor.white.withAlphaComponent(0.7)
        field.textColor = isDarkMode ? NSColor.white : NSColor.black
        field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        field.alignment = .center
        field.onCapture = { newBinding in
            binding = newBinding
            field.stringValue = newBinding.displayString
        }
        field.stringValue = binding.displayString
        return field
    }
    
    func updateNSView(_ nsView: KeyCaptureTextField, context: Context) {
        nsView.stringValue = binding.displayString
        nsView.backgroundColor = isDarkMode ? NSColor.black.withAlphaComponent(0.25) : NSColor.white.withAlphaComponent(0.7)
        nsView.textColor = isDarkMode ? NSColor.white : NSColor.black
    }
}

final class KeyCaptureTextField: NSTextField {
    var onCapture: ((KeyBinding) -> Void)?
    
    override var acceptsFirstResponder: Bool {
        true
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let binding = KeyBinding(keyCode: event.keyCode, modifiers: modifiers.rawValue)
        onCapture?(binding)
    }
}
