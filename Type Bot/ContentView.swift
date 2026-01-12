//
//  ContentView.swift
//  Type Bot
//
//  Created by Ryder Thomas on 1/9/26.
//

import SwiftUI
import AppKit
import ApplicationServices

struct ContentView: View {
    @StateObject private var settings = TypeBotSettings()
    @StateObject private var editorController = RichTextController()
    @StateObject private var engine = TypeBotEngine()
    @State private var richText = NSAttributedString(string: "")
    @State private var showSettings = false
    @State private var showAppPicker = false
    @State private var localMonitor: Any?
    @State private var accessGranted = AXIsProcessTrusted()
    @State private var selectedApp: NSRunningApplication?
    @State private var showAccessibilityPrompt = false
    @State private var showBackdrop = false
    @State private var blurRadius: CGFloat = 0
    @State private var didPrewarmBlur = false
    @State private var workspaceObserver: Any?
    @State private var showHumanizeSettings = false
    @State private var didPreloadHumanizeSettings = false
    @State private var humanizePreloadTask: Task<Void, Never>?
    private let popupAnimation: Animation = .linear(duration: 0.12)
    private var palette: Palette { Palette(isDarkMode: settings.isDarkMode) }
    private let savedRichTextURL: URL = {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let directory = appSupport?.appendingPathComponent("Type Bot", isDirectory: true)
        if let directory {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("lastDocument.rtf")
        }
        return fm.temporaryDirectory.appendingPathComponent("typebot-lastDocument.rtf")
    }()
    
    var body: some View {
        ZStack {
            backgroundLayer
            
            VStack(spacing: 18) {
                editorCard
                controlsRow
                statusRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .blur(radius: blurRadius)
            .saturation(showBackdrop ? 0.9 : 1)

            SettingsPanelView(isPresented: $showSettings, settings: settings)
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
                .opacity(showSettings ? 1 : 0)
                .allowsHitTesting(showSettings)
                .accessibilityHidden(!showSettings)
                .animation(popupAnimation, value: showSettings)
                .zIndex(2)
            
            if showBackdrop {
                Color.black.opacity(settings.isDarkMode ? 0.08 : 0.04)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissPopups()
                    }
            }
            
            if showAccessibilityPrompt {
                AccessibilityPromptView(isPresented: $showAccessibilityPrompt, isDarkMode: settings.isDarkMode) {
                    openAccessibilitySettings()
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
            }

            HumanizeSettingsView(isPresented: $showHumanizeSettings, settings: settings)
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
                .opacity(showHumanizeSettings ? 1 : 0)
                .allowsHitTesting(showHumanizeSettings)
                .accessibilityHidden(!showHumanizeSettings)
                .animation(popupAnimation, value: showHumanizeSettings)
                .zIndex(3)
        }
        .frame(minWidth: 760, minHeight: 620)
        .sheet(isPresented: $showAppPicker) {
            AppPickerView { app in
                selectedApp = app
                showAppPicker = false
                startTyping(with: app)
            } onCancel: {
                showAppPicker = false
            }
        }
        .onAppear {
            requestAccessibilityIfNeeded()
            setupKeyMonitor()
            setupWorkspaceMonitor()
            prewarmBlurIfNeeded()
            loadSavedRichText()
            if didPreloadHumanizeSettings == false {
                startHumanizePreload()
            }
        }
        .onChange(of: showSettings) { _, _ in
            updateBackdrop()
        }
        .onChange(of: showAccessibilityPrompt) { _, _ in
            updateBackdrop()
        }
        .onChange(of: showHumanizeSettings) { _, _ in
            updateBackdrop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requestAccessibilityIfNeeded()
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let observer = workspaceObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
            humanizePreloadTask?.cancel()
        }
    }
    
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                gradient: Gradient(colors: [palette.glow.opacity(0.4), .clear]),
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .blur(radius: 60)
            RadialGradient(
                gradient: Gradient(colors: [palette.accent.opacity(0.18), .clear]),
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 360
            )
            .blur(radius: 40)
            
            Circle()
                .fill(palette.accent.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 72)
                .offset(x: -260, y: -180)
            
            Circle()
                .fill(palette.glow.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 72)
                .offset(x: 220, y: 180)
        }
        .ignoresSafeArea()
    }
    
    private var editorCard: some View {
        EditorCardView(
            isDarkMode: settings.isDarkMode,
            richText: persistedRichTextBinding,
            controller: editorController
        )
    }
    
    private var controlsRow: some View {
        HStack(spacing: 14) {
            actionButton(
                title: engine.isTyping ? "Restart" : "Start",
                systemImage: "play.fill",
                gradient: [palette.success, palette.success.opacity(0.85)]
            ) {
                if engine.isTyping {
                    engine.stop()
                }
                showAppPicker = true
            }
            actionButton(
                title: engine.isPaused ? "Resume" : "Pause",
                systemImage: engine.isPaused ? "play.fill" : "pause.fill",
                gradient: [palette.warning, palette.warning.opacity(0.85)]
            ) {
                if engine.isPaused, let app = selectedApp {
                    app.activate(options: [.activateAllWindows])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        engine.pause()
                    }
                } else {
                    engine.pause()
                }
            }
            actionButton(
                title: "Stop",
                systemImage: "stop.fill",
                gradient: [palette.danger, palette.danger.opacity(0.85)]
            ) {
                engine.stop()
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Toggle(isOn: $settings.humanizeEnabled) {
                    Text("Realistic")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }
                .toggleStyle(.switch)
                .tint(palette.accent)
                
                Button {
                    presentHumanizeSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Tune")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 12, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(palette.surfaceStroke, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(palette.surfaceStroke, lineWidth: 1)
                    )
            )
        }
    }
    
    private func actionButton(title: String, systemImage: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 14, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .blendMode(.overlay)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var statusRow: some View {
        HStack(spacing: 12) {
            Text(engine.statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondaryText)
            Spacer()
            if let selectedAppName = selectedApp?.localizedName {
                Text("Target: \(selectedAppName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }
            HStack(spacing: 8) {
                Image(systemName: accessGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(accessGranted ? palette.accent : palette.warning)
                Text(accessGranted ? "Accessibility enabled" : "Enable Accessibility for typing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(palette.surfaceStroke, lineWidth: 1)
                )
        )
    }
    
    private func setupKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if showSettings {
                return event
            }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if modifiers.rawValue == settings.startKeyBinding.modifiers && event.keyCode == settings.startKeyBinding.keyCode {
                if engine.isTyping {
                    engine.stop()
                }
                showAppPicker = true
                return nil
            }
            if modifiers.rawValue == settings.pauseKeyBinding.modifiers && event.keyCode == settings.pauseKeyBinding.keyCode {
                engine.pause()
                return nil
            }
            if modifiers.rawValue == settings.stopKeyBinding.modifiers && event.keyCode == settings.stopKeyBinding.keyCode {
                engine.stop()
                return nil
            }
            return event
        }
    }

    private func setupWorkspaceMonitor() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard engine.isTyping, !engine.isPaused else { return }
            guard let target = selectedApp else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.processIdentifier != target.processIdentifier {
                engine.pause()
            }
        }
    }
    
    private func startTyping(with app: NSRunningApplication) {
        accessGranted = AXIsProcessTrusted()
        guard accessGranted else {
            engine.statusText = "Enable Accessibility in Settings"
            return
        }
        engine.start(attributedText: richText, targetApp: app, settings: settings, humanize: settings.humanizeEnabled)
    }
    
    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrusted()
        accessGranted = trusted
        guard trusted == false else {
            showAccessibilityPrompt = false
            showBackdrop = false
            blurRadius = 0
            return
        }
        if showBackdrop == false {
            showBackdrop = true
            blurRadius = 4
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        DispatchQueue.main.async {
            accessGranted = AXIsProcessTrustedWithOptions(options)
            if accessGranted == false && showAccessibilityPrompt == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                    showAccessibilityPrompt = true
                }
            }
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func presentSettings() {
        withAnimation(popupAnimation) {
            showBackdrop = true
            blurRadius = 4
            showSettings = true
        }
    }
    
    private func presentHumanizeSettings() {
        humanizePreloadTask?.cancel()
        didPreloadHumanizeSettings = true
        showBackdrop = true
        blurRadius = 4
        withAnimation(popupAnimation) {
            showHumanizeSettings = true
        }
    }
    
    private func dismissPopups() {
        withAnimation(popupAnimation) {
            showSettings = false
            showAccessibilityPrompt = false
        }
        withAnimation(popupAnimation) {
            showHumanizeSettings = false
        }
        humanizePreloadTask?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            updateBackdrop(animated: true)
        }
    }
    
    private func updateBackdrop(animated: Bool = false) {
        if showSettings || showAccessibilityPrompt || showHumanizeSettings {
            if animated {
                withAnimation(popupAnimation) {
                    showBackdrop = true
                    blurRadius = 4
                }
            } else {
                showBackdrop = true
                blurRadius = 4
            }
        } else {
            if animated {
                withAnimation(popupAnimation) {
                    showBackdrop = false
                    blurRadius = 0
                }
            } else {
                showBackdrop = false
                blurRadius = 0
            }
        }
    }
    
    private func prewarmBlurIfNeeded() {
        guard didPrewarmBlur == false else { return }
        didPrewarmBlur = true
        let transaction = Transaction(animation: .none)
        withTransaction(transaction) {
            blurRadius = 4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withTransaction(transaction) {
                updateBackdrop()
            }
        }
    }

    private var persistedRichTextBinding: Binding<NSAttributedString> {
        Binding(
            get: { richText },
            set: { newValue in
                richText = newValue
                saveRichText(newValue)
            }
        )
    }

    private func loadSavedRichText() {
        guard let data = try? Data(contentsOf: savedRichTextURL) else { return }
        if let loaded = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            richText = loaded
            DispatchQueue.main.async {
                editorController.refreshFormattingState()
            }
        }
    }

    private func saveRichText(_ text: NSAttributedString) {
        guard let data = try? text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return }
        try? data.write(to: savedRichTextURL, options: .atomic)
    }

    private func startHumanizePreload() {
        humanizePreloadTask?.cancel()

        let steps: [(String, Double)] = [
            ("Loading layout engine", 0.12),
            ("Caching slider clusters", 0.32),
            ("Warming pause presets", 0.55),
            ("Indexing mistake profiles", 0.78),
            ("Finalizing controls", 1.0)
        ]

        humanizePreloadTask = Task { @MainActor in
            for (message, progress) in steps {
                guard !Task.isCancelled else { return }
                _ = (message, progress) // still iterate to keep timing, but silent
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            didPreloadHumanizeSettings = true
        }
    }
}

#Preview {
    ContentView()
}

private struct Palette {
    let isDarkMode: Bool
    
    var background: [Color] {
        if isDarkMode {
            return [
                Color(red: 0.08, green: 0.1, blue: 0.14),
                Color(red: 0.05, green: 0.06, blue: 0.1)
            ]
        }
        return [
            Color(red: 0.76, green: 0.8, blue: 0.88),
            Color(red: 0.64, green: 0.7, blue: 0.78)
        ]
    }
    
    var surface: Color {
        if isDarkMode {
            return Color(red: 0.14, green: 0.17, blue: 0.22, opacity: 0.92)
        }
        return Color(red: 0.89, green: 0.92, blue: 0.96, opacity: 0.94)
    }
    
    var surfaceStroke: Color {
        if isDarkMode {
            return Color(red: 0.26, green: 0.32, blue: 0.42, opacity: 0.5)
        }
        return Color(red: 0.6, green: 0.66, blue: 0.76, opacity: 0.45)
    }
    
    var primaryText: Color {
        if isDarkMode {
            return Color(red: 0.9, green: 0.93, blue: 0.98)
        }
        return Color(red: 0.16, green: 0.2, blue: 0.28)
    }
    
    var secondaryText: Color {
        if isDarkMode {
            return Color(red: 0.76, green: 0.8, blue: 0.88)
        }
        return Color(red: 0.3, green: 0.35, blue: 0.44)
    }
    
    var accent: Color {
        Color(red: 0.48, green: 0.68, blue: 0.92)
    }
    
    var success: Color {
        Color(red: 0.24, green: 0.78, blue: 0.62)
    }
    
    var glow: Color {
        Color(red: 0.28, green: 0.42, blue: 0.6)
    }
    
    var warning: Color {
        Color(red: 0.98, green: 0.73, blue: 0.32)
    }
    
    var danger: Color {
        Color(red: 0.98, green: 0.36, blue: 0.4)
    }
    
    var shadow: Color {
        isDarkMode ? Color.black.opacity(0.45) : Color.black.opacity(0.12)
    }
}

struct EditorCardView: View {
    let isDarkMode: Bool
    @Binding var richText: NSAttributedString
    @ObservedObject var controller: RichTextController
    
    private let fontFamilies: [String] = [
        "SF Pro Text",
        "SF Pro Rounded",
        "Avenir Next",
        "Helvetica Neue",
        "Times New Roman",
        "Georgia",
        "Futura",
        "Menlo",
        "Courier New",
        "Hoefler Text"
    ]
    private let lineSpacingPresets: [CGFloat] = [1.0, 1.15, 1.18, 1.35, 1.6]
    
    var body: some View {
        let cardBackground = isDarkMode
            ? Color(red: 0.14, green: 0.17, blue: 0.22, opacity: 0.94)
            : Color(red: 0.88, green: 0.91, blue: 0.95, opacity: 0.96)
        let cardStroke = isDarkMode
            ? Color(red: 0.26, green: 0.32, blue: 0.42, opacity: 0.6)
            : Color(red: 0.62, green: 0.68, blue: 0.78, opacity: 0.45)
        let cardShadow = isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.16)
        let accent = Color(red: 0.48, green: 0.68, blue: 0.92)
        let documentBackground = isDarkMode
            ? Color(red: 0.11, green: 0.14, blue: 0.18)
            : Color(red: 0.92, green: 0.95, blue: 0.98)
        let documentStroke = isDarkMode
            ? Color(red: 0.28, green: 0.32, blue: 0.42, opacity: 0.7)
            : Color(red: 0.72, green: 0.78, blue: 0.86, opacity: 0.5)
        
        VStack(alignment: .leading, spacing: 12) {
            formattingToolbar(accent: accent)
            editorCanvas(
                documentBackground: documentBackground,
                documentStroke: documentStroke,
                accent: accent
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(cardBackground)
                .overlay(
                    LinearGradient(
                        colors: [accent.opacity(isDarkMode ? 0.16 : 0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(cardStroke, lineWidth: 1)
                )
        )
        .shadow(color: cardShadow, radius: 18, x: 0, y: 8)
    }
    
    private func formattingToolbar(accent: Color) -> some View {
        let toolbarFill = isDarkMode
            ? Color(red: 0.16, green: 0.19, blue: 0.24, opacity: 0.9)
            : Color(red: 0.9, green: 0.93, blue: 0.96)
        let toolbarStroke = isDarkMode
            ? Color(red: 0.24, green: 0.3, blue: 0.38, opacity: 0.6)
            : Color(red: 0.64, green: 0.7, blue: 0.8, opacity: 0.5)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                fontMenu
                sizeControl
                lineSpacingDropdown
                formattingStyleButtons
                Spacer()
                alignmentControls
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(toolbarFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(toolbarStroke, lineWidth: 1)
                )
        )
    }
    
    private var fontMenu: some View {
        let label = fontDisplayName(for: controller.fontName)
        return Menu {
            ForEach(fontFamilies, id: \.self) { font in
                Button {
                    controller.applyFont(named: font)
                } label: {
                    let isCurrent = fontDisplayName(for: controller.fontName) == fontDisplayName(for: font)
                    Label(fontDisplayName(for: font), systemImage: isCurrent ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "textformat.alt")
                Text(label)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
            )
        }
        .menuStyle(.borderlessButton)
    }
    
    private var sizeControl: some View {
        HStack(spacing: 6) {
            toolbarIconButton(icon: "minus", label: nil, isActive: false, minWidth: 28) {
                controller.adjustFontSize(by: -1)
            }
            Text("\(Int(controller.fontSize)) pt")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minWidth: 50)
            toolbarIconButton(icon: "plus", label: nil, isActive: false, minWidth: 28) {
                controller.adjustFontSize(by: 1)
            }
        }
    }
    
    private var lineSpacingDropdown: some View {
        let current = presetLabel(controller.lineHeightMultiple)
        return Menu {
            ForEach(lineSpacingPresets, id: \.self) { preset in
                let active = abs(controller.lineHeightMultiple - preset) < 0.01
                Button {
                    controller.setLineHeight(preset)
                } label: {
                    HStack {
                        Text("\(presetLabel(preset))×")
                        if active {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                Text("\(current)× spacing")
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
            )
        }
        .menuStyle(.borderlessButton)
    }
    
    private var alignmentControls: some View {
        HStack(spacing: 6) {
            toolbarIconButton(icon: "text.alignleft", label: nil, isActive: controller.alignment == .left, action: { controller.setAlignment(.left) })
            toolbarIconButton(icon: "text.aligncenter", label: nil, isActive: controller.alignment == .center, action: { controller.setAlignment(.center) })
            toolbarIconButton(icon: "text.alignright", label: nil, isActive: controller.alignment == .right, action: { controller.setAlignment(.right) })
            toolbarIconButton(icon: "text.justify", label: nil, isActive: controller.alignment == .justified, action: { controller.setAlignment(.justified) })
            toolbarIconButton(icon: "arrow.counterclockwise", label: "Reset", isActive: false, minWidth: 64) {
                controller.clearFormatting()
            }
        }
    }
    
    private var formattingStyleButtons: some View {
        HStack(spacing: 6) {
            toolbarIconButton(icon: "bold", label: nil, isActive: controller.isBold, action: controller.toggleBold)
            toolbarIconButton(icon: "italic", label: nil, isActive: controller.isItalic, action: controller.toggleItalic)
            toolbarIconButton(icon: "underline", label: nil, isActive: controller.isUnderline, action: controller.toggleUnderline)
            toolbarIconButton(icon: "strikethrough", label: nil, isActive: controller.isStrikethrough, action: controller.toggleStrikethrough)
        }
    }
    
    private func editorCanvas(documentBackground: Color, documentStroke: Color, accent: Color) -> some View {
        let topBar = LinearGradient(
            colors: [accent.opacity(isDarkMode ? 0.32 : 0.2), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(topBar)
                    .frame(width: 120, height: 6)
                Spacer()
                Capsule()
                    .fill(topBar.opacity(0.4))
                    .frame(width: 60, height: 6)
            }
            .padding(.horizontal, 4)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(documentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(documentStroke, lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 0) {
                    RichTextEditor(text: $richText, controller: controller, isDarkMode: isDarkMode)
                        .frame(minHeight: 280)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accent.opacity(0.08), lineWidth: 2)
            )
        }
    }
    
    private func toolbarIconButton(icon: String, label: String?, isActive: Bool, minWidth: CGFloat = 30, action: @escaping () -> Void) -> some View {
        let accent = Color(red: 0.32, green: 0.72, blue: 1.0)
        let inactiveFill = isDarkMode ? Color.white.opacity(0.08) : Color.white
        let activeFill = isDarkMode ? accent.opacity(0.24) : accent.opacity(0.16)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(isDarkMode ? .white : .black)
            .padding(.vertical, 8)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? activeFill : inactiveFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? accent.opacity(0.45) : Color.black.opacity(isDarkMode ? 0.05 : 0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func fontDisplayName(for name: String) -> String {
        if let font = NSFont(name: name, size: controller.fontSize) {
            return font.displayName ?? font.familyName ?? name
        }
        if name.contains(".SFNS") {
            return "SF Pro"
        }
        return name
    }
    
    private func presetLabel(_ preset: CGFloat) -> String {
        if preset == floor(preset) {
            return String(format: "%.0f", preset)
        }
        return String(format: "%.2f", Double(preset))
    }
}

struct HumanizeSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: TypeBotSettings
    
    var body: some View {
        let panelFill = LinearGradient(
            colors: settings.isDarkMode
            ? [Color(red: 0.08, green: 0.08, blue: 0.14), Color.black.opacity(0.92)]
            : [Color.white, Color(red: 0.95, green: 0.97, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let panelStroke = settings.isDarkMode ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
        let titleColor = settings.isDarkMode ? Color.white : Color.black
        let secondary = settings.isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
        let accent = Color(red: 0.32, green: 0.72, blue: 1.0)
        
        VStack(spacing: 18) {
            HStack {
                Text("Realistic Settings")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
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
                    settingsSection(title: "Ultra-run") {
                        Toggle(isOn: $settings.humanizeUltraRun) {
                            Text("Ultra-run")
                        }
                        settingsActionButton(title: "Randomize", systemImage: "shuffle", accent: accent) {
                            settings.randomizeHumanizeSettings()
                        }
                        Text("Adds long thinking pauses and slower pacing for essay-like writing.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(secondary)
                    }
                    
                    settingsSection(title: "Base Speed") {
                        sliderRow(title: "CPS Factor", value: $settings.humanizeBaseCpsFactor, range: 0.02...0.3, step: 0.01, suffix: "x")
                        sliderRow(title: "Min CPS", value: $settings.humanizeMinCps, range: 0.5...8.0, step: 0.5, suffix: " cps")
                        sliderRow(title: "Max CPS", value: $settings.humanizeMaxCps, range: 4.0...20.0, step: 0.5, suffix: " cps")
                        sliderRow(title: "Pace Min", value: $settings.humanizePaceMin, range: 0.3...1.2, step: 0.05, suffix: "x")
                        sliderRow(title: "Pace Max", value: $settings.humanizePaceMax, range: 1.0...2.5, step: 0.05, suffix: "x")
                        sliderRow(title: "Pace Jitter", value: $settings.humanizePaceJitter, range: 0.0...0.15, step: 0.01, suffix: "")
                    }
                    
                    settingsSection(title: "Wave") {
                        sliderRow(title: "Amplitude", value: $settings.humanizeWaveAmplitude, range: 0.0...0.6, step: 0.02, suffix: "")
                        sliderRow(title: "Speed Min", value: $settings.humanizeWaveSpeedMin, range: 0.005...0.08, step: 0.005, suffix: "")
                        sliderRow(title: "Speed Max", value: $settings.humanizeWaveSpeedMax, range: 0.02...0.14, step: 0.005, suffix: "")
                        sliderRow(title: "Speed Jitter", value: $settings.humanizeWaveSpeedJitter, range: 0.0...0.02, step: 0.001, suffix: "")
                        sliderRow(title: "Start Speed Min", value: $settings.humanizeWaveStartSpeedMin, range: 0.01...0.08, step: 0.005, suffix: "")
                        sliderRow(title: "Start Speed Max", value: $settings.humanizeWaveStartSpeedMax, range: 0.02...0.1, step: 0.005, suffix: "")
                    }
                    
                    settingsSection(title: "Burst") {
                        sliderRow(title: "Burst Chance", value: $settings.humanizeBurstChance, range: 0.0...0.2, step: 0.01, suffix: "")
                        intSliderRow(title: "Burst Min Len", value: $settings.humanizeBurstMinLen, range: 2...20)
                        intSliderRow(title: "Burst Max Len", value: $settings.humanizeBurstMaxLen, range: 4...30)
                        sliderRow(title: "Burst Pace Min", value: $settings.humanizeBurstMinPace, range: 0.4...1.2, step: 0.05, suffix: "x")
                        sliderRow(title: "Burst Pace Max", value: $settings.humanizeBurstMaxPace, range: 0.6...1.6, step: 0.05, suffix: "x")
                    }
                    
                    settingsSection(title: "Delay Bounds") {
                        sliderRow(title: "Jitter Min", value: $settings.humanizeJitterMin, range: 0.2...1.2, step: 0.05, suffix: "x")
                        sliderRow(title: "Jitter Max", value: $settings.humanizeJitterMax, range: 0.6...2.5, step: 0.05, suffix: "x")
                        sliderRow(title: "Delay Min Sec", value: $settings.humanizeDelayMinSeconds, range: 0.0...0.2, step: 0.01, suffix: "s")
                        sliderRow(title: "Delay Min Factor", value: $settings.humanizeDelayMinFactor, range: 0.2...1.5, step: 0.05, suffix: "x")
                        sliderRow(title: "Delay Max Sec", value: $settings.humanizeDelayMaxSeconds, range: 0.2...2.0, step: 0.05, suffix: "s")
                        sliderRow(title: "Delay Max Factor", value: $settings.humanizeDelayMaxFactor, range: 2.0...10.0, step: 0.5, suffix: "x")
                    }
                    
                    settingsSection(title: "Pauses") {
                        sliderRow(title: "Space Delay Min", value: $settings.humanizeSpaceDelayMin, range: 0.0...0.4, step: 0.01, suffix: "s")
                        sliderRow(title: "Space Delay Max", value: $settings.humanizeSpaceDelayMax, range: 0.05...0.6, step: 0.01, suffix: "s")
                        intSliderRow(title: "Word Pause Every Min", value: $settings.humanizeWordPauseEveryMin, range: 1...10)
                        intSliderRow(title: "Word Pause Every Max", value: $settings.humanizeWordPauseEveryMax, range: 2...16)
                        sliderRow(title: "Word Pause Extra Min", value: $settings.humanizeWordPauseExtraMin, range: 0.0...0.8, step: 0.02, suffix: "s")
                        sliderRow(title: "Word Pause Extra Max", value: $settings.humanizeWordPauseExtraMax, range: 0.05...1.2, step: 0.02, suffix: "s")
                        sliderRow(title: "Long Pause Chance", value: $settings.humanizeLongPauseChance, range: 0.0...0.1, step: 0.005, suffix: "")
                        sliderRow(title: "Long Pause Min", value: $settings.humanizeLongPauseMin, range: 0.3...2.5, step: 0.1, suffix: "s")
                        sliderRow(title: "Long Pause Max", value: $settings.humanizeLongPauseMax, range: 0.5...4.0, step: 0.1, suffix: "s")
                        intSliderRow(title: "Long Pause Cooldown Min", value: $settings.humanizeLongPauseCooldownMin, range: 2...20)
                        intSliderRow(title: "Long Pause Cooldown Max", value: $settings.humanizeLongPauseCooldownMax, range: 4...30)
                        sliderRow(title: "Newline Pause Min", value: $settings.humanizeNewlinePauseMin, range: 0.1...1.2, step: 0.05, suffix: "s")
                        sliderRow(title: "Newline Pause Max", value: $settings.humanizeNewlinePauseMax, range: 0.2...2.0, step: 0.05, suffix: "s")
                        sliderRow(title: "Sentence Pause Min", value: $settings.humanizeSentencePauseMin, range: 0.1...1.6, step: 0.05, suffix: "s")
                        sliderRow(title: "Sentence Pause Max", value: $settings.humanizeSentencePauseMax, range: 0.2...2.5, step: 0.05, suffix: "s")
                        sliderRow(title: "Clause Pause Min", value: $settings.humanizeClausePauseMin, range: 0.02...0.4, step: 0.01, suffix: "s")
                        sliderRow(title: "Clause Pause Max", value: $settings.humanizeClausePauseMax, range: 0.05...0.8, step: 0.01, suffix: "s")
                        sliderRow(title: "Random Pause Chance", value: $settings.humanizeRandomPauseChance, range: 0.0...0.2, step: 0.01, suffix: "")
                        sliderRow(title: "Random Pause Min", value: $settings.humanizeRandomPauseMin, range: 0.05...1.0, step: 0.05, suffix: "s")
                        sliderRow(title: "Random Pause Max", value: $settings.humanizeRandomPauseMax, range: 0.1...1.6, step: 0.05, suffix: "s")
                    }
                    
                    settingsSection(title: "Mistakes") {
                        sliderRow(title: "Base Chance", value: $settings.humanizeMistakeBase, range: 0.0...0.03, step: 0.001, suffix: "")
                        sliderRow(title: "Speed Factor", value: $settings.humanizeMistakeSpeedFactor, range: 0.0...0.06, step: 0.002, suffix: "")
                        sliderRow(title: "Burst Bonus", value: $settings.humanizeMistakeBurstBonus, range: 0.0...0.02, step: 0.001, suffix: "")
                        sliderRow(title: "Fatigue Chance", value: $settings.humanizeMistakeFatigueChance, range: 0.0...0.2, step: 0.01, suffix: "")
                        sliderRow(title: "Fatigue Bonus", value: $settings.humanizeMistakeFatigueBonus, range: 0.0...0.02, step: 0.001, suffix: "")
                        sliderRow(title: "Uppercase Mult", value: $settings.humanizeMistakeUppercaseMultiplier, range: 0.2...1.2, step: 0.05, suffix: "x")
                        sliderRow(title: "Max Lower", value: $settings.humanizeMistakeMaxLower, range: 0.01...0.2, step: 0.005, suffix: "")
                        sliderRow(title: "Max Upper", value: $settings.humanizeMistakeMaxUpper, range: 0.01...0.2, step: 0.005, suffix: "")
                        sliderRow(title: "Fix Now Weight", value: $settings.humanizeMistakeFixImmediateWeight, range: 0.0...5.0, step: 0.2, suffix: "")
                        sliderRow(title: "Fix Short Weight", value: $settings.humanizeMistakeFixShortWeight, range: 0.0...5.0, step: 0.2, suffix: "")
                        sliderRow(title: "Fix Medium Weight", value: $settings.humanizeMistakeFixMediumWeight, range: 0.0...5.0, step: 0.2, suffix: "")
                        sliderRow(title: "Fix Long Weight", value: $settings.humanizeMistakeFixLongWeight, range: 0.0...5.0, step: 0.2, suffix: "")
                        sliderRow(title: "Correction Pace Min", value: $settings.humanizeCorrectionPaceMin, range: 0.4...1.2, step: 0.05, suffix: "x")
                        sliderRow(title: "Correction Pace Max", value: $settings.humanizeCorrectionPaceMax, range: 0.6...1.8, step: 0.05, suffix: "x")
                        sliderRow(title: "Correction Pause Min", value: $settings.humanizeCorrectionPauseMin, range: 0.02...0.4, step: 0.01, suffix: "s")
                        sliderRow(title: "Correction Pause Max", value: $settings.humanizeCorrectionPauseMax, range: 0.05...0.6, step: 0.01, suffix: "s")
                        sliderRow(title: "Retype Pause Min", value: $settings.humanizeCorrectionRetypePauseMin, range: 0.01...0.3, step: 0.01, suffix: "s")
                        sliderRow(title: "Retype Pause Max", value: $settings.humanizeCorrectionRetypePauseMax, range: 0.02...0.5, step: 0.01, suffix: "s")
                        sliderRow(title: "Correction Min Delay", value: $settings.humanizeCorrectionMinDelaySeconds, range: 0.0...0.1, step: 0.005, suffix: "s")
                        sliderRow(title: "Correction Jitter Min", value: $settings.humanizeCorrectionJitterMin, range: 0.2...1.0, step: 0.05, suffix: "x")
                        sliderRow(title: "Correction Jitter Max", value: $settings.humanizeCorrectionJitterMax, range: 0.4...1.6, step: 0.05, suffix: "x")
                    }
                    
                    Text("Changes apply to new runs. Keep the target app focused while testing.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(secondary)
                    
                    settingsActionButton(title: "Reset to Defaults", systemImage: "arrow.counterclockwise", accent: accent) {
                        settings.resetHumanizeSettingsToDefaults()
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(panelStroke, lineWidth: 1)
                )
        )
        .shadow(color: settings.isDarkMode ? .black.opacity(0.5) : .black.opacity(0.12), radius: 26, x: 0, y: 12)
        .foregroundColor(settings.isDarkMode ? .white : .black)
    }
    
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        let fill = settings.isDarkMode ? Color.white.opacity(0.06) : Color.white.opacity(0.9)
        let stroke = settings.isDarkMode ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(settings.isDarkMode ? .white.opacity(0.82) : .black.opacity(0.7))
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
        }
    }
    
    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(format(value.wrappedValue))\(suffix)")
                    .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func settingsActionButton(title: String, systemImage: String, accent: Color, action: @escaping () -> Void) -> some View {
        let stroke = settings.isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.75), accent.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func intSliderRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        let binding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            Slider(value: binding, in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        }
    }
    
    private func format(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.3f", value)
    }
}

struct AccessibilityPromptView: View {
    @Binding var isPresented: Bool
    let isDarkMode: Bool
    var onOpenSettings: () -> Void
    
    var body: some View {
        let panelFill = isDarkMode ? Color.black.opacity(0.75) : Color.white.opacity(0.9)
        let panelStroke = isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
        let textColor = isDarkMode ? Color.white : Color.black
        let secondary = isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
        let accent = Color(red: 0.32, green: 0.72, blue: 1.0)
        
        VStack(spacing: 16) {
            Text("Enable Accessibility")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
            Text("Type Bot needs Accessibility permission to type into other apps.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Not Now") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Open Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(panelStroke, lineWidth: 1)
                )
        )
        .foregroundColor(textColor)
    }
}
