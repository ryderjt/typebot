import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

struct TypeRun {
    let text: String
    let bold: Bool
    let italic: Bool
    let underline: Bool
    let strikethrough: Bool
}

struct FormatState: Equatable {
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var strikethrough: Bool = false
}

final class TypeBotEngine: ObservableObject {
    @Published var isTyping = false
    @Published var isPaused = false
    @Published var statusText = "Idle"
    
    private var runs: [TypeRun] = []
    private var runIndex = 0
    private var charIndex = 0
    private var timer: DispatchSourceTimer?
    private var currentFormat = FormatState()
    private var settings: TypeBotSettings?
    private var targetApp: NSRunningApplication?
    private var humanizeEnabled = false
    private var humanizePace = 1.0
    private var nextHumanizedCharTime = 0.0
    private var humanizeTargetCps = 0.0
    private var humanizeBurstRemaining = 0
    private var humanizeBurstPace = 1.0
    private var humanizeWordPauseCounter = 0
    private var humanizeLongPauseCooldown = 0
    private var pendingMistake: PendingMistake?
    private var humanizeSpeedPhase = 0.0
    private var humanizeSpeedPhaseVelocity = 0.0
    
    private struct PendingMistake {
        enum Phase {
            case waiting
            case backspacing(remaining: Int)
            case retyping(index: Int)
        }
        
        var typedBuffer: [String]
        var intendedBuffer: [String]
        var charsBeforeFix: Int
        var typedSinceMistake: Int
        var phase: Phase
        var correctionPace: Double
    }
    
    private let adjacencyMap: [Character: [Character]] = [
        "q": ["w", "a"],
        "w": ["q", "e", "s"],
        "e": ["w", "r", "d"],
        "r": ["e", "t", "f"],
        "t": ["r", "y", "g"],
        "y": ["t", "u", "h"],
        "u": ["y", "i", "j"],
        "i": ["u", "o", "k"],
        "o": ["i", "p", "l"],
        "p": ["o"],
        "a": ["q", "w", "s", "z"],
        "s": ["a", "w", "e", "d", "x"],
        "d": ["s", "e", "r", "f", "c"],
        "f": ["d", "r", "t", "g", "v"],
        "g": ["f", "t", "y", "h", "b"],
        "h": ["g", "y", "u", "j", "n"],
        "j": ["h", "u", "i", "k", "m"],
        "k": ["j", "i", "o", "l"],
        "l": ["k", "o", "p"],
        "z": ["a", "s", "x"],
        "x": ["z", "s", "d", "c"],
        "c": ["x", "d", "f", "v"],
        "v": ["c", "f", "g", "b"],
        "b": ["v", "g", "h", "n"],
        "n": ["b", "h", "j", "m"],
        "m": ["n", "j", "k"]
    ]
    
    func start(attributedText: NSAttributedString, targetApp: NSRunningApplication, settings: TypeBotSettings, humanize: Bool) {
        guard !isTyping else { return }
        let parsedRuns = TypeBotEngine.parseRuns(from: attributedText)
        guard !parsedRuns.isEmpty else {
            statusText = "No text to type"
            return
        }
        self.settings = settings
        self.targetApp = targetApp
        humanizeEnabled = humanize
        humanizePace = 1.0
        let minCps = min(settings.humanizeMinCps, settings.humanizeMaxCps)
        let maxCps = max(settings.humanizeMinCps, settings.humanizeMaxCps)
        let baseCps = settings.typingSpeed * settings.humanizeBaseCpsFactor
        let ultraMultiplier = settings.humanizeUltraRun ? 0.7 : 1.0
        humanizeTargetCps = max(minCps, min(baseCps * ultraMultiplier, maxCps))
        humanizeBurstRemaining = 0
        humanizeBurstPace = 1.0
        humanizeWordPauseCounter = 0
        humanizeLongPauseCooldown = 0
        humanizeSpeedPhase = Double.random(in: 0...Double.pi * 2)
        let waveStartMin = min(settings.humanizeWaveStartSpeedMin, settings.humanizeWaveStartSpeedMax)
        let waveStartMax = max(settings.humanizeWaveStartSpeedMin, settings.humanizeWaveStartSpeedMax)
        humanizeSpeedPhaseVelocity = Double.random(in: waveStartMin...waveStartMax)
        pendingMistake = nil
        runs = parsedRuns
        runIndex = 0
        charIndex = 0
        currentFormat = FormatState()
        isTyping = true
        isPaused = false
        statusText = "Activating \(targetApp.localizedName ?? "App")…"
        
        targetApp.activate(options: [.activateAllWindows])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.activationDelay) { [weak self] in
            guard let self, self.isTyping else { return }
            self.beginTypingLoop()
        }
    }
    
    func pause() {
        guard isTyping else { return }
        isPaused.toggle()
        statusText = isPaused ? "Paused" : "Typing…"
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
        isTyping = false
        isPaused = false
        statusText = "Stopped"
    }
    
    private func beginTypingLoop() {
        statusText = "Typing…"
        let interval = humanizeEnabled ? 0.01 : 0.02
        if humanizeEnabled {
            nextHumanizedCharTime = CFAbsoluteTimeGetCurrent()
        }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.typeNextChunk(interval: interval)
        }
        self.timer = timer
        timer.resume()
    }
    
    private func typeNextChunk(interval: Double) {
        if humanizeEnabled {
            typeNextHumanizedChar(now: CFAbsoluteTimeGetCurrent())
            return
        }
        guard isTyping, !isPaused, let settings else { return }
        if runIndex >= runs.count {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
                self?.statusText = "Done"
            }
            return
        }
        let charsPerTick = max(1, Int(settings.typingSpeed * interval))
        var remaining = charsPerTick
        while remaining > 0 && runIndex < runs.count {
            let run = runs[runIndex]
            if charIndex == 0 {
                syncFormatting(for: run, settings: settings)
            }
            let remainingInRun = run.text.count - charIndex
            let takeCount = min(remaining, remainingInRun)
            let chunk = substring(run.text, offset: charIndex, length: takeCount)
            sendText(chunk)
            charIndex += takeCount
            remaining -= takeCount
            if charIndex >= run.text.count {
                runIndex += 1
                charIndex = 0
            }
        }
    }

    private func typeNextHumanizedChar(now: Double) {
        guard isTyping, !isPaused, let settings else { return }
        guard now >= nextHumanizedCharTime else { return }
        if handlePendingMistake(now: now, settings: settings) {
            return
        }
        if runIndex >= runs.count {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
                self?.statusText = "Done"
            }
            return
        }
        let run = runs[runIndex]
        if charIndex == 0 {
            syncFormatting(for: run, settings: settings)
        }
        let chunk = substring(run.text, offset: charIndex, length: 1)
        if let mistake = maybeCreateMistake(for: chunk, settings: settings) {
            if let wrongChar = mistake.typedBuffer.first {
                sendText(wrongChar)
            }
            pendingMistake = mistake
            charIndex += 1
            if charIndex >= run.text.count {
                runIndex += 1
                charIndex = 0
            }
            if runIndex >= runs.count {
                DispatchQueue.main.async { [weak self] in
                    self?.stop()
                    self?.statusText = "Done"
                }
                return
            }
            let nextChar = nextCharacter()
            let delay = humanizedDelay(after: chunk, nextChar: nextChar, settings: settings) + Double.random(in: 0.01...0.04)
            nextHumanizedCharTime = now + delay
            return
        }
        sendText(chunk)
        charIndex += 1
        appendToPendingMistakeBufferIfWaiting(typedChar: chunk)
        if charIndex >= run.text.count {
            runIndex += 1
            charIndex = 0
        }
        if runIndex >= runs.count {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
                self?.statusText = "Done"
            }
            return
        }
        let nextChar = nextCharacter()
        let delay = humanizedDelay(after: chunk, nextChar: nextChar, settings: settings)
        nextHumanizedCharTime = now + delay
    }

    private func humanizedDelay(after typedChar: String, nextChar: String?, settings: TypeBotSettings) -> Double {
        let baseDelay = 1.0 / max(1.0, humanizeTargetCps)
        let paceJitter = abs(settings.humanizePaceJitter)
        humanizePace += Double.random(in: -paceJitter...paceJitter)
        let paceMin = min(settings.humanizePaceMin, settings.humanizePaceMax)
        let paceMax = max(settings.humanizePaceMin, settings.humanizePaceMax)
        humanizePace = min(max(humanizePace, paceMin), paceMax)
        let waveJitter = abs(settings.humanizeWaveSpeedJitter)
        humanizeSpeedPhaseVelocity += Double.random(in: -waveJitter...waveJitter)
        let waveMin = min(settings.humanizeWaveSpeedMin, settings.humanizeWaveSpeedMax)
        let waveMax = max(settings.humanizeWaveSpeedMin, settings.humanizeWaveSpeedMax)
        humanizeSpeedPhaseVelocity = min(max(humanizeSpeedPhaseVelocity, waveMin), waveMax)
        humanizeSpeedPhase += humanizeSpeedPhaseVelocity
        let slowWave = 1.0 + settings.humanizeWaveAmplitude * sin(humanizeSpeedPhase)
        if humanizeBurstRemaining <= 0 && Double.random(in: 0...1) < settings.humanizeBurstChance {
            let burstMinLen = min(settings.humanizeBurstMinLen, settings.humanizeBurstMaxLen)
            let burstMaxLen = max(settings.humanizeBurstMinLen, settings.humanizeBurstMaxLen)
            humanizeBurstRemaining = Int.random(in: burstMinLen...burstMaxLen)
            let burstMinPace = min(settings.humanizeBurstMinPace, settings.humanizeBurstMaxPace)
            let burstMaxPace = max(settings.humanizeBurstMinPace, settings.humanizeBurstMaxPace)
            humanizeBurstPace = Double.random(in: burstMinPace...burstMaxPace)
        }
        if humanizeBurstRemaining > 0 {
            humanizeBurstRemaining -= 1
        } else {
            humanizeBurstPace = 1.0
        }
        let jitterMin = min(settings.humanizeJitterMin, settings.humanizeJitterMax)
        let jitterMax = max(settings.humanizeJitterMin, settings.humanizeJitterMax)
        let jitter = Double.random(in: jitterMin...jitterMax)
        var delay = baseDelay * humanizePace * humanizeBurstPace * slowWave * jitter
        let minDelay = max(settings.humanizeDelayMinSeconds, baseDelay * settings.humanizeDelayMinFactor)
        let maxDelay = max(settings.humanizeDelayMaxSeconds, baseDelay * settings.humanizeDelayMaxFactor)
        delay = min(max(delay, minDelay), maxDelay)
        if typedChar == " " {
            let spaceMin = min(settings.humanizeSpaceDelayMin, settings.humanizeSpaceDelayMax)
            let spaceMax = max(settings.humanizeSpaceDelayMin, settings.humanizeSpaceDelayMax)
            delay += Double.random(in: spaceMin...spaceMax)
            humanizeWordPauseCounter += 1
            let wordMin = min(settings.humanizeWordPauseEveryMin, settings.humanizeWordPauseEveryMax)
            let wordMax = max(settings.humanizeWordPauseEveryMin, settings.humanizeWordPauseEveryMax)
            if humanizeWordPauseCounter >= Int.random(in: wordMin...wordMax) {
                let pauseMin = min(settings.humanizeWordPauseExtraMin, settings.humanizeWordPauseExtraMax)
                let pauseMax = max(settings.humanizeWordPauseExtraMin, settings.humanizeWordPauseExtraMax)
                delay += Double.random(in: pauseMin...pauseMax)
                humanizeWordPauseCounter = 0
            }
            if humanizeLongPauseCooldown > 0 {
                humanizeLongPauseCooldown -= 1
            } else if Double.random(in: 0...1) < settings.humanizeLongPauseChance {
                let longMin = min(settings.humanizeLongPauseMin, settings.humanizeLongPauseMax)
                let longMax = max(settings.humanizeLongPauseMin, settings.humanizeLongPauseMax)
                delay += Double.random(in: longMin...longMax)
                let cooldownMin = min(settings.humanizeLongPauseCooldownMin, settings.humanizeLongPauseCooldownMax)
                let cooldownMax = max(settings.humanizeLongPauseCooldownMin, settings.humanizeLongPauseCooldownMax)
                humanizeLongPauseCooldown = Int.random(in: cooldownMin...cooldownMax)
            }
            if settings.humanizeUltraRun, Double.random(in: 0...1) < 0.02 {
                delay += Double.random(in: 1.0...4.0)
            }
        } else if typedChar == "\n" {
            let lineMin = min(settings.humanizeNewlinePauseMin, settings.humanizeNewlinePauseMax)
            let lineMax = max(settings.humanizeNewlinePauseMin, settings.humanizeNewlinePauseMax)
            delay += Double.random(in: lineMin...lineMax)
            if settings.humanizeUltraRun {
                delay += Double.random(in: 0.8...4.0)
            }
        } else if isSentenceBoundary(after: typedChar, nextChar: nextChar) {
            let sentenceMin = min(settings.humanizeSentencePauseMin, settings.humanizeSentencePauseMax)
            let sentenceMax = max(settings.humanizeSentencePauseMin, settings.humanizeSentencePauseMax)
            delay += Double.random(in: sentenceMin...sentenceMax)
            if settings.humanizeUltraRun, Double.random(in: 0...1) < 0.35 {
                delay += Double.random(in: 2.0...30.0)
            }
        } else if isClauseBoundary(typedChar) {
            let clauseMin = min(settings.humanizeClausePauseMin, settings.humanizeClausePauseMax)
            let clauseMax = max(settings.humanizeClausePauseMin, settings.humanizeClausePauseMax)
            delay += Double.random(in: clauseMin...clauseMax)
            if settings.humanizeUltraRun {
                delay += Double.random(in: 0.2...1.2)
            }
        }
        if Double.random(in: 0...1) < settings.humanizeRandomPauseChance {
            let randomMin = min(settings.humanizeRandomPauseMin, settings.humanizeRandomPauseMax)
            let randomMax = max(settings.humanizeRandomPauseMin, settings.humanizeRandomPauseMax)
            delay += Double.random(in: randomMin...randomMax)
        }
        return delay
    }

    private func isSentenceBoundary(after typedChar: String, nextChar: String?) -> Bool {
        guard let scalar = typedChar.unicodeScalars.first else { return false }
        let enders = CharacterSet(charactersIn: ".!?")
        guard enders.contains(scalar) else { return false }
        guard let nextChar else { return true }
        guard let nextScalar = nextChar.unicodeScalars.first else { return true }
        return CharacterSet.whitespacesAndNewlines.contains(nextScalar)
    }

    private func isClauseBoundary(_ typedChar: String) -> Bool {
        guard let scalar = typedChar.unicodeScalars.first else { return false }
        let enders = CharacterSet(charactersIn: ",;:")
        return enders.contains(scalar)
    }

    private func nextCharacter() -> String? {
        guard runIndex < runs.count else { return nil }
        let run = runs[runIndex]
        guard charIndex < run.text.count else { return nil }
        return substring(run.text, offset: charIndex, length: 1)
    }
    
    private func handlePendingMistake(now: Double, settings: TypeBotSettings) -> Bool {
        guard var mistake = pendingMistake else { return false }
        switch mistake.phase {
        case .waiting:
            if mistake.typedSinceMistake >= mistake.charsBeforeFix {
                mistake.phase = .backspacing(remaining: mistake.typedBuffer.count)
                pendingMistake = mistake
                let pauseMin = min(settings.humanizeCorrectionPauseMin, settings.humanizeCorrectionPauseMax)
                let pauseMax = max(settings.humanizeCorrectionPauseMin, settings.humanizeCorrectionPauseMax)
                nextHumanizedCharTime = now + Double.random(in: pauseMin...pauseMax)
                return true
            }
            return false
        case .backspacing(let remaining):
            guard remaining > 0 else {
                mistake.phase = .retyping(index: 0)
                pendingMistake = mistake
                let pauseMin = min(settings.humanizeCorrectionRetypePauseMin, settings.humanizeCorrectionRetypePauseMax)
                let pauseMax = max(settings.humanizeCorrectionRetypePauseMin, settings.humanizeCorrectionRetypePauseMax)
                nextHumanizedCharTime = now + Double.random(in: pauseMin...pauseMax)
                return true
            }
            sendBackspace()
            let nextRemaining = remaining - 1
            mistake.phase = .backspacing(remaining: nextRemaining)
            pendingMistake = mistake
            nextHumanizedCharTime = now + correctionKeystrokeDelay(base: mistake.correctionPace, settings: settings)
            return true
        case .retyping(let index):
            guard index < mistake.intendedBuffer.count else {
                pendingMistake = nil
                return false
            }
            let char = mistake.intendedBuffer[index]
            sendText(char)
            let nextIndex = index + 1
            if nextIndex >= mistake.intendedBuffer.count {
                pendingMistake = nil
            } else {
                mistake.phase = .retyping(index: nextIndex)
                pendingMistake = mistake
            }
            nextHumanizedCharTime = now + correctionKeystrokeDelay(base: mistake.correctionPace, settings: settings)
            return true
        }
    }
    
    private func appendToPendingMistakeBufferIfWaiting(typedChar: String) {
        guard var mistake = pendingMistake else { return }
        guard case .waiting = mistake.phase else { return }
        mistake.typedBuffer.append(typedChar)
        mistake.intendedBuffer.append(typedChar)
        mistake.typedSinceMistake += 1
        pendingMistake = mistake
    }
    
    private func maybeCreateMistake(for intendedChar: String, settings: TypeBotSettings) -> PendingMistake? {
        guard pendingMistake == nil else { return nil }
        guard let char = intendedChar.first else { return nil }
        guard let wrongChar = adjacentKey(for: char) else { return nil }
        let chance = mistakeProbability(for: char, settings: settings)
        guard Double.random(in: 0...1) < chance else { return nil }
        let charsBeforeFix = weightedMistakeFixDelay(settings: settings)
        let paceMin = min(settings.humanizeCorrectionPaceMin, settings.humanizeCorrectionPaceMax)
        let paceMax = max(settings.humanizeCorrectionPaceMin, settings.humanizeCorrectionPaceMax)
        let correctionPace = Double.random(in: paceMin...paceMax)
        return PendingMistake(
            typedBuffer: [String(wrongChar)],
            intendedBuffer: [intendedChar],
            charsBeforeFix: charsBeforeFix,
            typedSinceMistake: 0,
            phase: .waiting,
            correctionPace: correctionPace
        )
    }
    
    private func mistakeProbability(for char: Character, settings: TypeBotSettings) -> Double {
        let letters = CharacterSet.letters
        guard let scalar = String(char).unicodeScalars.first, letters.contains(scalar) else {
            return 0.0
        }
        let speedFactor = min(max(settings.typingSpeed / 260.0, 0.0), 1.0)
        let burstFactor = humanizeBurstRemaining > 0 ? settings.humanizeMistakeBurstBonus : 0.0
        let fatigue = Double.random(in: 0...1) < settings.humanizeMistakeFatigueChance ? settings.humanizeMistakeFatigueBonus : 0.0
        let base = settings.humanizeMistakeBase + speedFactor * settings.humanizeMistakeSpeedFactor + burstFactor + fatigue
        if char.isUppercase {
            return min(base * settings.humanizeMistakeUppercaseMultiplier, settings.humanizeMistakeMaxUpper)
        }
        return min(base, settings.humanizeMistakeMaxLower)
    }
    
    private func adjacentKey(for char: Character) -> Character? {
        let lower = Character(String(char).lowercased())
        guard let neighbors = adjacencyMap[lower], let picked = neighbors.randomElement() else { return nil }
        if String(char).uppercased() == String(char) {
            return Character(String(picked).uppercased())
        }
        return picked
    }
    
    private func correctionKeystrokeDelay(base: Double, settings: TypeBotSettings) -> Double {
        let baseDelay = 1.0 / max(1.0, humanizeTargetCps)
        let jitterMin = min(settings.humanizeCorrectionJitterMin, settings.humanizeCorrectionJitterMax)
        let jitterMax = max(settings.humanizeCorrectionJitterMin, settings.humanizeCorrectionJitterMax)
        let jitter = Double.random(in: jitterMin...jitterMax)
        return max(settings.humanizeCorrectionMinDelaySeconds, baseDelay * base * jitter)
    }

    private func weightedMistakeFixDelay(settings: TypeBotSettings) -> Int {
        let options: [(Int, Double)] = [
            (0, max(0.0, settings.humanizeMistakeFixImmediateWeight)),
            (1, max(0.0, settings.humanizeMistakeFixShortWeight)),
            (2, max(0.0, settings.humanizeMistakeFixMediumWeight)),
            (3, max(0.0, settings.humanizeMistakeFixLongWeight))
        ]
        let total = options.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        let roll = Double.random(in: 0..<total)
        var running = 0.0
        for (delay, weight) in options {
            running += weight
            if roll <= running {
                return delay
            }
        }
        return 0
    }
    
    private func sendBackspace() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Delete), keyDown: true) else { return }
        let up = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Delete), keyDown: false)
        down.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func sendReturn() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Return), keyDown: true) else { return }
        let up = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Return), keyDown: false)
        down.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func sendSpace() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Space), keyDown: true) else { return }
        let up = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Space), keyDown: false)
        down.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
    
    private func syncFormatting(for run: TypeRun, settings: TypeBotSettings) {
        if settings.useBoldShortcut && currentFormat.bold != run.bold {
            sendShortcut(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])
            currentFormat.bold = run.bold
        }
        if settings.useItalicShortcut && currentFormat.italic != run.italic {
            sendShortcut(keyCode: UInt16(kVK_ANSI_I), modifiers: [.command])
            currentFormat.italic = run.italic
        }
        if settings.useUnderlineShortcut && currentFormat.underline != run.underline {
            sendShortcut(keyCode: UInt16(kVK_ANSI_U), modifiers: [.command])
            currentFormat.underline = run.underline
        }
        if settings.useStrikethroughShortcut && currentFormat.strikethrough != run.strikethrough {
            sendShortcut(keyCode: UInt16(kVK_ANSI_X), modifiers: [.command, .shift])
            currentFormat.strikethrough = run.strikethrough
        }
    }
    
    private func sendText(_ text: String) {
        var previousWasCarriageReturn = false
        for scalar in text.unicodeScalars {
            guard scalar.value <= 0xFFFF else { continue }
            if scalar == "\r" {
                sendReturn()
                previousWasCarriageReturn = true
                continue
            }
            if scalar == "\n" {
                if previousWasCarriageReturn {
                    previousWasCarriageReturn = false
                    continue
                }
                sendReturn()
                continue
            }
            previousWasCarriageReturn = false
            if scalar == " " {
                sendSpace()
                continue
            }
            if CharacterSet.newlines.contains(scalar) {
                sendReturn()
                continue
            }
            var char = UniChar(scalar.value)
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
            down.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
    
    private func sendShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        down.flags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        up?.flags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))
        down.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
    
    static func parseRuns(from attributedText: NSAttributedString) -> [TypeRun] {
        guard attributedText.length > 0 else { return [] }
        var results: [TypeRun] = []
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attributes, range, _ in
            let substring = attributedText.attributedSubstring(from: range).string
            if substring.isEmpty { return }
            let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let traits = NSFontManager.shared.traits(of: font)
            let bold = traits.contains(.boldFontMask)
            let italic = traits.contains(.italicFontMask)
            let underline = (attributes[.underlineStyle] as? Int ?? 0) != 0
            let strikethrough = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
            results.append(TypeRun(text: substring, bold: bold, italic: italic, underline: underline, strikethrough: strikethrough))
        }
        return results
    }
    
    private func substring(_ text: String, offset: Int, length: Int) -> String {
        guard offset >= 0, length > 0 else { return "" }
        let start = text.index(text.startIndex, offsetBy: offset)
        let end = text.index(start, offsetBy: length)
        return String(text[start..<end])
    }
}
