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
    @State private var showHumanizePreload = false
    @State private var humanizePreloadProgress = 0.0
    @State private var humanizePreloadMessage = "Preparing Realistic Settings"
    @State private var didPreloadHumanizeSettings = false
    @State private var humanizePreloadTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: settings.isDarkMode ?
                    [Color(red: 0.08, green: 0.08, blue: 0.08), Color(red: 0.05, green: 0.05, blue: 0.05)] :
                    [Color(red: 0.98, green: 0.98, blue: 0.98), Color(red: 0.94, green: 0.94, blue: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 18) {
                header
                editorCard
                controlsRow
                Spacer(minLength: 0)
                statusRow
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.4), value: settings.isDarkMode)
            .blur(radius: blurRadius)
            .saturation(showBackdrop ? 0.9 : 1)
            
            if showBackdrop {
                Color.black.opacity(settings.isDarkMode ? 0.08 : 0.04)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissPopups()
                    }
            }
            
            if showSettings {
                SettingsPanelView(isPresented: $showSettings, settings: settings)
                    .padding(.vertical, 40)
                    .padding(.horizontal, 24)
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

            if showHumanizePreload {
                HumanizeSettingsView(isPresented: .constant(false), settings: settings)
                    .opacity(0.001)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                HumanizePreloadView(
                    isDarkMode: settings.isDarkMode,
                    progress: humanizePreloadProgress,
                    message: humanizePreloadMessage
                )
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale))
            }
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
        .onChange(of: showHumanizePreload) { _, _ in
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
    
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Type Bot")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(settings.isDarkMode ? .white : .black)
                Text("Paste rich text, pick a window, and let Type Bot do the typing.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            
            Spacer()
            
            Button {
                presentSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(settings.isDarkMode ? .white : .black)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(settings.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var editorCard: some View {
        EditorCardView(
            isDarkMode: settings.isDarkMode,
            richText: $richText,
            controller: editorController
        )
    }
    
    private var controlsRow: some View {
        HStack(spacing: 14) {
            actionButton(title: engine.isTyping ? "Restart" : "Start", systemImage: "play.fill", color: Color(red: 0.2, green: 0.8, blue: 0.5)) {
                if engine.isTyping {
                    engine.stop()
                }
                showAppPicker = true
            }
            actionButton(title: engine.isPaused ? "Resume" : "Pause", systemImage: engine.isPaused ? "play.fill" : "pause.fill", color: Color(red: 0.95, green: 0.75, blue: 0.2)) {
                if engine.isPaused, let app = selectedApp {
                    app.activate(options: [.activateAllWindows])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        engine.pause()
                    }
                } else {
                    engine.pause()
                }
            }
            actionButton(title: "Stop", systemImage: "stop.fill", color: Color(red: 0.95, green: 0.35, blue: 0.3)) {
                engine.stop()
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Toggle("Realistic", isOn: $settings.humanizeEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                Button {
                    showHumanizeSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(settings.isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func actionButton(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
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
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: color.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    private var statusRow: some View {
        HStack(spacing: 12) {
            Text(engine.statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            Spacer()
            if let selectedAppName = selectedApp?.localizedName {
                Text("Target: \(selectedAppName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            HStack(spacing: 8) {
                Image(systemName: accessGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(accessGranted ? .green : .orange)
                Text(accessGranted ? "Accessibility enabled" : "Enable Accessibility for typing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(settings.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
        }
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
        showBackdrop = true
        blurRadius = 4
        showSettings = true
    }
    
    private func dismissPopups() {
        showSettings = false
        showAccessibilityPrompt = false
        showHumanizeSettings = false
        showHumanizePreload = false
        humanizePreloadTask?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            updateBackdrop()
        }
    }
    
    private func updateBackdrop() {
        if showSettings || showAccessibilityPrompt || showHumanizeSettings || showHumanizePreload {
            showBackdrop = true
            blurRadius = 4
        } else {
            showBackdrop = false
            blurRadius = 0
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

    private func startHumanizePreload() {
        humanizePreloadTask?.cancel()
        humanizePreloadProgress = 0
        humanizePreloadMessage = "Preparing Realistic Settings"
        showBackdrop = true
        blurRadius = 4
        showHumanizePreload = true

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
                humanizePreloadMessage = message
                withAnimation(.easeInOut(duration: 0.18)) {
                    humanizePreloadProgress = progress
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            didPreloadHumanizeSettings = true
            showHumanizePreload = false
            updateBackdrop()
        }
    }
}

#Preview {
    ContentView()
}

struct EditorCardView: View {
    let isDarkMode: Bool
    @Binding var richText: NSAttributedString
    @ObservedObject var controller: RichTextController
    
    var body: some View {
        let toolbarBackground = isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.6)
        let editorBackground = isDarkMode ? Color.black.opacity(0.35) : Color.white.opacity(0.9)
        let editorStroke = isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
        let cardBackground = isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
        let cardStroke = isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.1)
        let cardShadow = isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.1)
        
        let toolbarShape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 18
        )
        let editorShape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 0
        )
        let cardShape = RoundedRectangle(cornerRadius: 22)
        
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Formatting")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                
                Spacer()
                
                toolbarButton(icon: "bold", isActive: controller.isBold, action: controller.toggleBold)
                toolbarButton(icon: "italic", isActive: controller.isItalic, action: controller.toggleItalic)
                toolbarButton(icon: "underline", isActive: controller.isUnderline, action: controller.toggleUnderline)
                toolbarButton(icon: "strikethrough", isActive: controller.isStrikethrough, action: controller.toggleStrikethrough)
                toolbarButton(icon: "textformat", isActive: false, action: controller.clearFormatting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                toolbarShape.fill(toolbarBackground)
            )
            .overlay(
                Rectangle()
                    .fill(editorStroke)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            )
            
            RichTextEditor(text: $richText, controller: controller, isDarkMode: isDarkMode)
                .frame(minHeight: 260)
                .padding(12)
                .background(
                    editorShape.fill(editorBackground)
                )
                .overlay(
                    editorShape.stroke(editorStroke, lineWidth: 1)
                )
        }
        .background(
            cardShape.fill(cardBackground)
        )
        .overlay(
            cardShape.stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 18, x: 0, y: 8)
    }
    
    private func toolbarButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        let inactiveFill = isDarkMode ? Color.black.opacity(0.3) : Color.white.opacity(0.9)
        let activeFill = isDarkMode ? Color.white.opacity(0.22) : Color.black.opacity(0.12)
        let activeStroke = isDarkMode ? Color.white.opacity(0.35) : Color.black.opacity(0.2)
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? activeFill : inactiveFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isActive ? activeStroke : .clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct HumanizeSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: TypeBotSettings
    
    var body: some View {
        let panelFill = settings.isDarkMode ? Color.black.opacity(0.72) : Color.white.opacity(0.92)
        let panelStroke = settings.isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
        let titleColor = settings.isDarkMode ? Color.white : Color.black
        let secondary = settings.isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
        
        VStack(spacing: 18) {
            HStack {
                Text("Realistic Settings")
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
                    settingsSection(title: "Ultra-run") {
                        Toggle(isOn: $settings.humanizeUltraRun) {
                            Text("Ultra-run")
                        }
                        settingsActionButton(title: "Randomize", systemImage: "shuffle") {
                            settings.randomizeHumanizeSettings()
                        }
                        Text("Adds long thinking pauses and slower pacing for essay-like writing.")
                            .font(.system(size: 12))
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondary)
                    
                    settingsActionButton(title: "Reset to Defaults", systemImage: "arrow.counterclockwise") {
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
        .foregroundColor(settings.isDarkMode ? .white : .black)
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

    private func settingsActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        let accent = settings.isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
        let stroke = settings.isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(settings.isDarkMode ? .white : .black)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent)
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

struct HumanizePreloadView: View {
    let isDarkMode: Bool
    let progress: Double
    let message: String

    var body: some View {
        let panelFill = isDarkMode ? Color.black.opacity(0.78) : Color.white.opacity(0.92)
        let panelStroke = isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
        let titleColor = isDarkMode ? Color.white : Color.black
        let secondary = isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
        let barBackground = isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        let barFill = isDarkMode ? Color.white.opacity(0.9) : Color.black.opacity(0.75)
        let percent = Int((progress * 100).rounded())

        VStack(spacing: 16) {
            Text("Loading Realistic Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(titleColor)

            VStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barBackground)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barFill)
                        .frame(width: max(16, CGFloat(progress) * 280), height: 10)
                }
                Text("\(message) • \(percent)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(panelStroke, lineWidth: 1)
                )
        )
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
        
        VStack(spacing: 16) {
            Text("Enable Accessibility")
                .font(.system(size: 20, weight: .bold))
            Text("Type Bot needs Accessibility permission to type into other apps.")
                .font(.system(size: 13))
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
