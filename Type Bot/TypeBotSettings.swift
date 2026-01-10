import SwiftUI
import AppKit
import Carbon.HIToolbox
import Combine

struct KeyBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt
    
    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { parts.append("Cmd") }
        if flags.contains(.option) { parts.append("Option") }
        if flags.contains(.control) { parts.append("Control") }
        if flags.contains(.shift) { parts.append("Shift") }
        let keyName = KeyBinding.keyName(for: keyCode)
        if !keyName.isEmpty { parts.append(keyName) }
        return parts.joined(separator: "+")
    }
    
    static func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Return: return "Return"
        case kVK_Escape: return "Esc"
        case kVK_Space: return "Space"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        default: return ""
        }
    }
    
    static let startDefault = KeyBinding(keyCode: UInt16(kVK_ANSI_S), modifiers: NSEvent.ModifierFlags.command.union(.shift).rawValue)
    static let pauseDefault = KeyBinding(keyCode: UInt16(kVK_ANSI_P), modifiers: NSEvent.ModifierFlags.command.union(.shift).rawValue)
    static let stopDefault = KeyBinding(keyCode: UInt16(kVK_ANSI_K), modifiers: NSEvent.ModifierFlags.command.union(.shift).rawValue)
}

final class TypeBotSettings: ObservableObject {
    private struct HumanizeDefaults {
        static let baseCpsFactor = 0.12
        static let minCps = 2.0
        static let maxCps = 10.0
        static let paceMin = 0.65
        static let paceMax = 1.55
        static let paceJitter = 0.06
        static let burstChance = 0.08
        static let burstMinLen = 6
        static let burstMaxLen = 16
        static let burstMinPace = 0.75
        static let burstMaxPace = 1.1
        static let jitterMin = 0.7
        static let jitterMax = 1.45
        static let delayMinSeconds = 0.03
        static let delayMinFactor = 0.6
        static let delayMaxSeconds = 0.85
        static let delayMaxFactor = 6.0
        static let waveAmplitude = 0.22
        static let waveSpeedMin = 0.02
        static let waveSpeedMax = 0.09
        static let waveSpeedJitter = 0.003
        static let waveStartSpeedMin = 0.035
        static let waveStartSpeedMax = 0.065
        static let spaceDelayMin = 0.06
        static let spaceDelayMax = 0.2
        static let wordPauseEveryMin = 3
        static let wordPauseEveryMax = 8
        static let wordPauseExtraMin = 0.12
        static let wordPauseExtraMax = 0.45
        static let longPauseChance = 0.02
        static let longPauseMin = 0.9
        static let longPauseMax = 2.4
        static let longPauseCooldownMin = 6
        static let longPauseCooldownMax = 16
        static let newlinePauseMin = 0.35
        static let newlinePauseMax = 0.9
        static let sentencePauseMin = 0.45
        static let sentencePauseMax = 1.2
        static let clausePauseMin = 0.08
        static let clausePauseMax = 0.28
        static let randomPauseChance = 0.06
        static let randomPauseMin = 0.25
        static let randomPauseMax = 0.8
        static let mistakeBase = 0.008
        static let mistakeSpeedFactor = 0.02
        static let mistakeBurstBonus = 0.005
        static let mistakeFatigueChance = 0.08
        static let mistakeFatigueBonus = 0.004
        static let mistakeUppercaseMultiplier = 0.8
        static let mistakeMaxLower = 0.06
        static let mistakeMaxUpper = 0.05
        static let mistakeFixImmediateWeight = 2.0
        static let mistakeFixShortWeight = 2.0
        static let mistakeFixMediumWeight = 1.0
        static let mistakeFixLongWeight = 1.0
        static let correctionPaceMin = 0.8
        static let correctionPaceMax = 1.25
        static let correctionPauseMin = 0.1
        static let correctionPauseMax = 0.22
        static let correctionRetypePauseMin = 0.05
        static let correctionRetypePauseMax = 0.12
        static let correctionMinDelaySeconds = 0.028
        static let correctionJitterMin = 0.6
        static let correctionJitterMax = 1.05
    }
    @Published var isDarkMode: Bool { didSet { UserDefaults.standard.set(isDarkMode, forKey: "typebot.isDarkMode") } }
    @Published var typingSpeed: Double { didSet { UserDefaults.standard.set(typingSpeed, forKey: "typebot.typingSpeed") } }
    @Published var activationDelay: Double { didSet { UserDefaults.standard.set(activationDelay, forKey: "typebot.activationDelay") } }
    @Published var useBoldShortcut: Bool { didSet { UserDefaults.standard.set(useBoldShortcut, forKey: "typebot.useBoldShortcut") } }
    @Published var useItalicShortcut: Bool { didSet { UserDefaults.standard.set(useItalicShortcut, forKey: "typebot.useItalicShortcut") } }
    @Published var useUnderlineShortcut: Bool { didSet { UserDefaults.standard.set(useUnderlineShortcut, forKey: "typebot.useUnderlineShortcut") } }
    @Published var useStrikethroughShortcut: Bool { didSet { UserDefaults.standard.set(useStrikethroughShortcut, forKey: "typebot.useStrikethroughShortcut") } }
    @Published var humanizeEnabled: Bool { didSet { UserDefaults.standard.set(humanizeEnabled, forKey: "typebot.humanizeEnabled") } }
    @Published var humanizeUltraRun: Bool { didSet { UserDefaults.standard.set(humanizeUltraRun, forKey: "typebot.humanizeUltraRun") } }
    @Published var humanizeBaseCpsFactor: Double { didSet { saveDouble(humanizeBaseCpsFactor, key: "typebot.humanizeBaseCpsFactor") } }
    @Published var humanizeMinCps: Double { didSet { saveDouble(humanizeMinCps, key: "typebot.humanizeMinCps") } }
    @Published var humanizeMaxCps: Double { didSet { saveDouble(humanizeMaxCps, key: "typebot.humanizeMaxCps") } }
    @Published var humanizePaceMin: Double { didSet { saveDouble(humanizePaceMin, key: "typebot.humanizePaceMin") } }
    @Published var humanizePaceMax: Double { didSet { saveDouble(humanizePaceMax, key: "typebot.humanizePaceMax") } }
    @Published var humanizePaceJitter: Double { didSet { saveDouble(humanizePaceJitter, key: "typebot.humanizePaceJitter") } }
    @Published var humanizeBurstChance: Double { didSet { saveDouble(humanizeBurstChance, key: "typebot.humanizeBurstChance") } }
    @Published var humanizeBurstMinLen: Int { didSet { saveInt(humanizeBurstMinLen, key: "typebot.humanizeBurstMinLen") } }
    @Published var humanizeBurstMaxLen: Int { didSet { saveInt(humanizeBurstMaxLen, key: "typebot.humanizeBurstMaxLen") } }
    @Published var humanizeBurstMinPace: Double { didSet { saveDouble(humanizeBurstMinPace, key: "typebot.humanizeBurstMinPace") } }
    @Published var humanizeBurstMaxPace: Double { didSet { saveDouble(humanizeBurstMaxPace, key: "typebot.humanizeBurstMaxPace") } }
    @Published var humanizeJitterMin: Double { didSet { saveDouble(humanizeJitterMin, key: "typebot.humanizeJitterMin") } }
    @Published var humanizeJitterMax: Double { didSet { saveDouble(humanizeJitterMax, key: "typebot.humanizeJitterMax") } }
    @Published var humanizeDelayMinSeconds: Double { didSet { saveDouble(humanizeDelayMinSeconds, key: "typebot.humanizeDelayMinSeconds") } }
    @Published var humanizeDelayMinFactor: Double { didSet { saveDouble(humanizeDelayMinFactor, key: "typebot.humanizeDelayMinFactor") } }
    @Published var humanizeDelayMaxSeconds: Double { didSet { saveDouble(humanizeDelayMaxSeconds, key: "typebot.humanizeDelayMaxSeconds") } }
    @Published var humanizeDelayMaxFactor: Double { didSet { saveDouble(humanizeDelayMaxFactor, key: "typebot.humanizeDelayMaxFactor") } }
    @Published var humanizeWaveAmplitude: Double { didSet { saveDouble(humanizeWaveAmplitude, key: "typebot.humanizeWaveAmplitude") } }
    @Published var humanizeWaveSpeedMin: Double { didSet { saveDouble(humanizeWaveSpeedMin, key: "typebot.humanizeWaveSpeedMin") } }
    @Published var humanizeWaveSpeedMax: Double { didSet { saveDouble(humanizeWaveSpeedMax, key: "typebot.humanizeWaveSpeedMax") } }
    @Published var humanizeWaveSpeedJitter: Double { didSet { saveDouble(humanizeWaveSpeedJitter, key: "typebot.humanizeWaveSpeedJitter") } }
    @Published var humanizeWaveStartSpeedMin: Double { didSet { saveDouble(humanizeWaveStartSpeedMin, key: "typebot.humanizeWaveStartSpeedMin") } }
    @Published var humanizeWaveStartSpeedMax: Double { didSet { saveDouble(humanizeWaveStartSpeedMax, key: "typebot.humanizeWaveStartSpeedMax") } }
    @Published var humanizeSpaceDelayMin: Double { didSet { saveDouble(humanizeSpaceDelayMin, key: "typebot.humanizeSpaceDelayMin") } }
    @Published var humanizeSpaceDelayMax: Double { didSet { saveDouble(humanizeSpaceDelayMax, key: "typebot.humanizeSpaceDelayMax") } }
    @Published var humanizeWordPauseEveryMin: Int { didSet { saveInt(humanizeWordPauseEveryMin, key: "typebot.humanizeWordPauseEveryMin") } }
    @Published var humanizeWordPauseEveryMax: Int { didSet { saveInt(humanizeWordPauseEveryMax, key: "typebot.humanizeWordPauseEveryMax") } }
    @Published var humanizeWordPauseExtraMin: Double { didSet { saveDouble(humanizeWordPauseExtraMin, key: "typebot.humanizeWordPauseExtraMin") } }
    @Published var humanizeWordPauseExtraMax: Double { didSet { saveDouble(humanizeWordPauseExtraMax, key: "typebot.humanizeWordPauseExtraMax") } }
    @Published var humanizeLongPauseChance: Double { didSet { saveDouble(humanizeLongPauseChance, key: "typebot.humanizeLongPauseChance") } }
    @Published var humanizeLongPauseMin: Double { didSet { saveDouble(humanizeLongPauseMin, key: "typebot.humanizeLongPauseMin") } }
    @Published var humanizeLongPauseMax: Double { didSet { saveDouble(humanizeLongPauseMax, key: "typebot.humanizeLongPauseMax") } }
    @Published var humanizeLongPauseCooldownMin: Int { didSet { saveInt(humanizeLongPauseCooldownMin, key: "typebot.humanizeLongPauseCooldownMin") } }
    @Published var humanizeLongPauseCooldownMax: Int { didSet { saveInt(humanizeLongPauseCooldownMax, key: "typebot.humanizeLongPauseCooldownMax") } }
    @Published var humanizeNewlinePauseMin: Double { didSet { saveDouble(humanizeNewlinePauseMin, key: "typebot.humanizeNewlinePauseMin") } }
    @Published var humanizeNewlinePauseMax: Double { didSet { saveDouble(humanizeNewlinePauseMax, key: "typebot.humanizeNewlinePauseMax") } }
    @Published var humanizeSentencePauseMin: Double { didSet { saveDouble(humanizeSentencePauseMin, key: "typebot.humanizeSentencePauseMin") } }
    @Published var humanizeSentencePauseMax: Double { didSet { saveDouble(humanizeSentencePauseMax, key: "typebot.humanizeSentencePauseMax") } }
    @Published var humanizeClausePauseMin: Double { didSet { saveDouble(humanizeClausePauseMin, key: "typebot.humanizeClausePauseMin") } }
    @Published var humanizeClausePauseMax: Double { didSet { saveDouble(humanizeClausePauseMax, key: "typebot.humanizeClausePauseMax") } }
    @Published var humanizeRandomPauseChance: Double { didSet { saveDouble(humanizeRandomPauseChance, key: "typebot.humanizeRandomPauseChance") } }
    @Published var humanizeRandomPauseMin: Double { didSet { saveDouble(humanizeRandomPauseMin, key: "typebot.humanizeRandomPauseMin") } }
    @Published var humanizeRandomPauseMax: Double { didSet { saveDouble(humanizeRandomPauseMax, key: "typebot.humanizeRandomPauseMax") } }
    @Published var humanizeMistakeBase: Double { didSet { saveDouble(humanizeMistakeBase, key: "typebot.humanizeMistakeBase") } }
    @Published var humanizeMistakeSpeedFactor: Double { didSet { saveDouble(humanizeMistakeSpeedFactor, key: "typebot.humanizeMistakeSpeedFactor") } }
    @Published var humanizeMistakeBurstBonus: Double { didSet { saveDouble(humanizeMistakeBurstBonus, key: "typebot.humanizeMistakeBurstBonus") } }
    @Published var humanizeMistakeFatigueChance: Double { didSet { saveDouble(humanizeMistakeFatigueChance, key: "typebot.humanizeMistakeFatigueChance") } }
    @Published var humanizeMistakeFatigueBonus: Double { didSet { saveDouble(humanizeMistakeFatigueBonus, key: "typebot.humanizeMistakeFatigueBonus") } }
    @Published var humanizeMistakeUppercaseMultiplier: Double { didSet { saveDouble(humanizeMistakeUppercaseMultiplier, key: "typebot.humanizeMistakeUppercaseMultiplier") } }
    @Published var humanizeMistakeMaxLower: Double { didSet { saveDouble(humanizeMistakeMaxLower, key: "typebot.humanizeMistakeMaxLower") } }
    @Published var humanizeMistakeMaxUpper: Double { didSet { saveDouble(humanizeMistakeMaxUpper, key: "typebot.humanizeMistakeMaxUpper") } }
    @Published var humanizeMistakeFixImmediateWeight: Double { didSet { saveDouble(humanizeMistakeFixImmediateWeight, key: "typebot.humanizeMistakeFixImmediateWeight") } }
    @Published var humanizeMistakeFixShortWeight: Double { didSet { saveDouble(humanizeMistakeFixShortWeight, key: "typebot.humanizeMistakeFixShortWeight") } }
    @Published var humanizeMistakeFixMediumWeight: Double { didSet { saveDouble(humanizeMistakeFixMediumWeight, key: "typebot.humanizeMistakeFixMediumWeight") } }
    @Published var humanizeMistakeFixLongWeight: Double { didSet { saveDouble(humanizeMistakeFixLongWeight, key: "typebot.humanizeMistakeFixLongWeight") } }
    @Published var humanizeCorrectionPaceMin: Double { didSet { saveDouble(humanizeCorrectionPaceMin, key: "typebot.humanizeCorrectionPaceMin") } }
    @Published var humanizeCorrectionPaceMax: Double { didSet { saveDouble(humanizeCorrectionPaceMax, key: "typebot.humanizeCorrectionPaceMax") } }
    @Published var humanizeCorrectionPauseMin: Double { didSet { saveDouble(humanizeCorrectionPauseMin, key: "typebot.humanizeCorrectionPauseMin") } }
    @Published var humanizeCorrectionPauseMax: Double { didSet { saveDouble(humanizeCorrectionPauseMax, key: "typebot.humanizeCorrectionPauseMax") } }
    @Published var humanizeCorrectionRetypePauseMin: Double { didSet { saveDouble(humanizeCorrectionRetypePauseMin, key: "typebot.humanizeCorrectionRetypePauseMin") } }
    @Published var humanizeCorrectionRetypePauseMax: Double { didSet { saveDouble(humanizeCorrectionRetypePauseMax, key: "typebot.humanizeCorrectionRetypePauseMax") } }
    @Published var humanizeCorrectionMinDelaySeconds: Double { didSet { saveDouble(humanizeCorrectionMinDelaySeconds, key: "typebot.humanizeCorrectionMinDelaySeconds") } }
    @Published var humanizeCorrectionJitterMin: Double { didSet { saveDouble(humanizeCorrectionJitterMin, key: "typebot.humanizeCorrectionJitterMin") } }
    @Published var humanizeCorrectionJitterMax: Double { didSet { saveDouble(humanizeCorrectionJitterMax, key: "typebot.humanizeCorrectionJitterMax") } }
    @Published var startKeyBinding: KeyBinding { didSet { saveKeyBinding(startKeyBinding, key: "typebot.startKeyBinding") } }
    @Published var pauseKeyBinding: KeyBinding { didSet { saveKeyBinding(pauseKeyBinding, key: "typebot.pauseKeyBinding") } }
    @Published var stopKeyBinding: KeyBinding { didSet { saveKeyBinding(stopKeyBinding, key: "typebot.stopKeyBinding") } }
    
    init() {
        isDarkMode = UserDefaults.standard.object(forKey: "typebot.isDarkMode") as? Bool ?? true
        typingSpeed = UserDefaults.standard.object(forKey: "typebot.typingSpeed") as? Double ?? 120
        activationDelay = UserDefaults.standard.object(forKey: "typebot.activationDelay") as? Double ?? 0.6
        useBoldShortcut = UserDefaults.standard.object(forKey: "typebot.useBoldShortcut") as? Bool ?? true
        useItalicShortcut = UserDefaults.standard.object(forKey: "typebot.useItalicShortcut") as? Bool ?? true
        useUnderlineShortcut = UserDefaults.standard.object(forKey: "typebot.useUnderlineShortcut") as? Bool ?? true
        useStrikethroughShortcut = UserDefaults.standard.object(forKey: "typebot.useStrikethroughShortcut") as? Bool ?? true
        humanizeEnabled = UserDefaults.standard.object(forKey: "typebot.humanizeEnabled") as? Bool ?? false
        humanizeUltraRun = UserDefaults.standard.object(forKey: "typebot.humanizeUltraRun") as? Bool ?? false
        humanizeBaseCpsFactor = Self.loadDouble(key: "typebot.humanizeBaseCpsFactor", fallback: HumanizeDefaults.baseCpsFactor)
        humanizeMinCps = Self.loadDouble(key: "typebot.humanizeMinCps", fallback: HumanizeDefaults.minCps)
        humanizeMaxCps = Self.loadDouble(key: "typebot.humanizeMaxCps", fallback: HumanizeDefaults.maxCps)
        humanizePaceMin = Self.loadDouble(key: "typebot.humanizePaceMin", fallback: HumanizeDefaults.paceMin)
        humanizePaceMax = Self.loadDouble(key: "typebot.humanizePaceMax", fallback: HumanizeDefaults.paceMax)
        humanizePaceJitter = Self.loadDouble(key: "typebot.humanizePaceJitter", fallback: HumanizeDefaults.paceJitter)
        humanizeBurstChance = Self.loadDouble(key: "typebot.humanizeBurstChance", fallback: HumanizeDefaults.burstChance)
        humanizeBurstMinLen = Self.loadInt(key: "typebot.humanizeBurstMinLen", fallback: HumanizeDefaults.burstMinLen)
        humanizeBurstMaxLen = Self.loadInt(key: "typebot.humanizeBurstMaxLen", fallback: HumanizeDefaults.burstMaxLen)
        humanizeBurstMinPace = Self.loadDouble(key: "typebot.humanizeBurstMinPace", fallback: HumanizeDefaults.burstMinPace)
        humanizeBurstMaxPace = Self.loadDouble(key: "typebot.humanizeBurstMaxPace", fallback: HumanizeDefaults.burstMaxPace)
        humanizeJitterMin = Self.loadDouble(key: "typebot.humanizeJitterMin", fallback: HumanizeDefaults.jitterMin)
        humanizeJitterMax = Self.loadDouble(key: "typebot.humanizeJitterMax", fallback: HumanizeDefaults.jitterMax)
        humanizeDelayMinSeconds = Self.loadDouble(key: "typebot.humanizeDelayMinSeconds", fallback: HumanizeDefaults.delayMinSeconds)
        humanizeDelayMinFactor = Self.loadDouble(key: "typebot.humanizeDelayMinFactor", fallback: HumanizeDefaults.delayMinFactor)
        humanizeDelayMaxSeconds = Self.loadDouble(key: "typebot.humanizeDelayMaxSeconds", fallback: HumanizeDefaults.delayMaxSeconds)
        humanizeDelayMaxFactor = Self.loadDouble(key: "typebot.humanizeDelayMaxFactor", fallback: HumanizeDefaults.delayMaxFactor)
        humanizeWaveAmplitude = Self.loadDouble(key: "typebot.humanizeWaveAmplitude", fallback: HumanizeDefaults.waveAmplitude)
        humanizeWaveSpeedMin = Self.loadDouble(key: "typebot.humanizeWaveSpeedMin", fallback: HumanizeDefaults.waveSpeedMin)
        humanizeWaveSpeedMax = Self.loadDouble(key: "typebot.humanizeWaveSpeedMax", fallback: HumanizeDefaults.waveSpeedMax)
        humanizeWaveSpeedJitter = Self.loadDouble(key: "typebot.humanizeWaveSpeedJitter", fallback: HumanizeDefaults.waveSpeedJitter)
        humanizeWaveStartSpeedMin = Self.loadDouble(key: "typebot.humanizeWaveStartSpeedMin", fallback: HumanizeDefaults.waveStartSpeedMin)
        humanizeWaveStartSpeedMax = Self.loadDouble(key: "typebot.humanizeWaveStartSpeedMax", fallback: HumanizeDefaults.waveStartSpeedMax)
        humanizeSpaceDelayMin = Self.loadDouble(key: "typebot.humanizeSpaceDelayMin", fallback: HumanizeDefaults.spaceDelayMin)
        humanizeSpaceDelayMax = Self.loadDouble(key: "typebot.humanizeSpaceDelayMax", fallback: HumanizeDefaults.spaceDelayMax)
        humanizeWordPauseEveryMin = Self.loadInt(key: "typebot.humanizeWordPauseEveryMin", fallback: HumanizeDefaults.wordPauseEveryMin)
        humanizeWordPauseEveryMax = Self.loadInt(key: "typebot.humanizeWordPauseEveryMax", fallback: HumanizeDefaults.wordPauseEveryMax)
        humanizeWordPauseExtraMin = Self.loadDouble(key: "typebot.humanizeWordPauseExtraMin", fallback: HumanizeDefaults.wordPauseExtraMin)
        humanizeWordPauseExtraMax = Self.loadDouble(key: "typebot.humanizeWordPauseExtraMax", fallback: HumanizeDefaults.wordPauseExtraMax)
        humanizeLongPauseChance = Self.loadDouble(key: "typebot.humanizeLongPauseChance", fallback: HumanizeDefaults.longPauseChance)
        humanizeLongPauseMin = Self.loadDouble(key: "typebot.humanizeLongPauseMin", fallback: HumanizeDefaults.longPauseMin)
        humanizeLongPauseMax = Self.loadDouble(key: "typebot.humanizeLongPauseMax", fallback: HumanizeDefaults.longPauseMax)
        humanizeLongPauseCooldownMin = Self.loadInt(key: "typebot.humanizeLongPauseCooldownMin", fallback: HumanizeDefaults.longPauseCooldownMin)
        humanizeLongPauseCooldownMax = Self.loadInt(key: "typebot.humanizeLongPauseCooldownMax", fallback: HumanizeDefaults.longPauseCooldownMax)
        humanizeNewlinePauseMin = Self.loadDouble(key: "typebot.humanizeNewlinePauseMin", fallback: HumanizeDefaults.newlinePauseMin)
        humanizeNewlinePauseMax = Self.loadDouble(key: "typebot.humanizeNewlinePauseMax", fallback: HumanizeDefaults.newlinePauseMax)
        humanizeSentencePauseMin = Self.loadDouble(key: "typebot.humanizeSentencePauseMin", fallback: HumanizeDefaults.sentencePauseMin)
        humanizeSentencePauseMax = Self.loadDouble(key: "typebot.humanizeSentencePauseMax", fallback: HumanizeDefaults.sentencePauseMax)
        humanizeClausePauseMin = Self.loadDouble(key: "typebot.humanizeClausePauseMin", fallback: HumanizeDefaults.clausePauseMin)
        humanizeClausePauseMax = Self.loadDouble(key: "typebot.humanizeClausePauseMax", fallback: HumanizeDefaults.clausePauseMax)
        humanizeRandomPauseChance = Self.loadDouble(key: "typebot.humanizeRandomPauseChance", fallback: HumanizeDefaults.randomPauseChance)
        humanizeRandomPauseMin = Self.loadDouble(key: "typebot.humanizeRandomPauseMin", fallback: HumanizeDefaults.randomPauseMin)
        humanizeRandomPauseMax = Self.loadDouble(key: "typebot.humanizeRandomPauseMax", fallback: HumanizeDefaults.randomPauseMax)
        humanizeMistakeBase = Self.loadDouble(key: "typebot.humanizeMistakeBase", fallback: HumanizeDefaults.mistakeBase)
        humanizeMistakeSpeedFactor = Self.loadDouble(key: "typebot.humanizeMistakeSpeedFactor", fallback: HumanizeDefaults.mistakeSpeedFactor)
        humanizeMistakeBurstBonus = Self.loadDouble(key: "typebot.humanizeMistakeBurstBonus", fallback: HumanizeDefaults.mistakeBurstBonus)
        humanizeMistakeFatigueChance = Self.loadDouble(key: "typebot.humanizeMistakeFatigueChance", fallback: HumanizeDefaults.mistakeFatigueChance)
        humanizeMistakeFatigueBonus = Self.loadDouble(key: "typebot.humanizeMistakeFatigueBonus", fallback: HumanizeDefaults.mistakeFatigueBonus)
        humanizeMistakeUppercaseMultiplier = Self.loadDouble(key: "typebot.humanizeMistakeUppercaseMultiplier", fallback: HumanizeDefaults.mistakeUppercaseMultiplier)
        humanizeMistakeMaxLower = Self.loadDouble(key: "typebot.humanizeMistakeMaxLower", fallback: HumanizeDefaults.mistakeMaxLower)
        humanizeMistakeMaxUpper = Self.loadDouble(key: "typebot.humanizeMistakeMaxUpper", fallback: HumanizeDefaults.mistakeMaxUpper)
        humanizeMistakeFixImmediateWeight = Self.loadDouble(key: "typebot.humanizeMistakeFixImmediateWeight", fallback: HumanizeDefaults.mistakeFixImmediateWeight)
        humanizeMistakeFixShortWeight = Self.loadDouble(key: "typebot.humanizeMistakeFixShortWeight", fallback: HumanizeDefaults.mistakeFixShortWeight)
        humanizeMistakeFixMediumWeight = Self.loadDouble(key: "typebot.humanizeMistakeFixMediumWeight", fallback: HumanizeDefaults.mistakeFixMediumWeight)
        humanizeMistakeFixLongWeight = Self.loadDouble(key: "typebot.humanizeMistakeFixLongWeight", fallback: HumanizeDefaults.mistakeFixLongWeight)
        humanizeCorrectionPaceMin = Self.loadDouble(key: "typebot.humanizeCorrectionPaceMin", fallback: HumanizeDefaults.correctionPaceMin)
        humanizeCorrectionPaceMax = Self.loadDouble(key: "typebot.humanizeCorrectionPaceMax", fallback: HumanizeDefaults.correctionPaceMax)
        humanizeCorrectionPauseMin = Self.loadDouble(key: "typebot.humanizeCorrectionPauseMin", fallback: HumanizeDefaults.correctionPauseMin)
        humanizeCorrectionPauseMax = Self.loadDouble(key: "typebot.humanizeCorrectionPauseMax", fallback: HumanizeDefaults.correctionPauseMax)
        humanizeCorrectionRetypePauseMin = Self.loadDouble(key: "typebot.humanizeCorrectionRetypePauseMin", fallback: HumanizeDefaults.correctionRetypePauseMin)
        humanizeCorrectionRetypePauseMax = Self.loadDouble(key: "typebot.humanizeCorrectionRetypePauseMax", fallback: HumanizeDefaults.correctionRetypePauseMax)
        humanizeCorrectionMinDelaySeconds = Self.loadDouble(key: "typebot.humanizeCorrectionMinDelaySeconds", fallback: HumanizeDefaults.correctionMinDelaySeconds)
        humanizeCorrectionJitterMin = Self.loadDouble(key: "typebot.humanizeCorrectionJitterMin", fallback: HumanizeDefaults.correctionJitterMin)
        humanizeCorrectionJitterMax = Self.loadDouble(key: "typebot.humanizeCorrectionJitterMax", fallback: HumanizeDefaults.correctionJitterMax)
        startKeyBinding = Self.loadKeyBinding(key: "typebot.startKeyBinding", fallback: .startDefault)
        pauseKeyBinding = Self.loadKeyBinding(key: "typebot.pauseKeyBinding", fallback: .pauseDefault)
        stopKeyBinding = Self.loadKeyBinding(key: "typebot.stopKeyBinding", fallback: .stopDefault)
    }

    func resetHumanizeSettingsToDefaults() {
        humanizeUltraRun = false
        humanizeBaseCpsFactor = HumanizeDefaults.baseCpsFactor
        humanizeMinCps = HumanizeDefaults.minCps
        humanizeMaxCps = HumanizeDefaults.maxCps
        humanizePaceMin = HumanizeDefaults.paceMin
        humanizePaceMax = HumanizeDefaults.paceMax
        humanizePaceJitter = HumanizeDefaults.paceJitter
        humanizeBurstChance = HumanizeDefaults.burstChance
        humanizeBurstMinLen = HumanizeDefaults.burstMinLen
        humanizeBurstMaxLen = HumanizeDefaults.burstMaxLen
        humanizeBurstMinPace = HumanizeDefaults.burstMinPace
        humanizeBurstMaxPace = HumanizeDefaults.burstMaxPace
        humanizeJitterMin = HumanizeDefaults.jitterMin
        humanizeJitterMax = HumanizeDefaults.jitterMax
        humanizeDelayMinSeconds = HumanizeDefaults.delayMinSeconds
        humanizeDelayMinFactor = HumanizeDefaults.delayMinFactor
        humanizeDelayMaxSeconds = HumanizeDefaults.delayMaxSeconds
        humanizeDelayMaxFactor = HumanizeDefaults.delayMaxFactor
        humanizeWaveAmplitude = HumanizeDefaults.waveAmplitude
        humanizeWaveSpeedMin = HumanizeDefaults.waveSpeedMin
        humanizeWaveSpeedMax = HumanizeDefaults.waveSpeedMax
        humanizeWaveSpeedJitter = HumanizeDefaults.waveSpeedJitter
        humanizeWaveStartSpeedMin = HumanizeDefaults.waveStartSpeedMin
        humanizeWaveStartSpeedMax = HumanizeDefaults.waveStartSpeedMax
        humanizeSpaceDelayMin = HumanizeDefaults.spaceDelayMin
        humanizeSpaceDelayMax = HumanizeDefaults.spaceDelayMax
        humanizeWordPauseEveryMin = HumanizeDefaults.wordPauseEveryMin
        humanizeWordPauseEveryMax = HumanizeDefaults.wordPauseEveryMax
        humanizeWordPauseExtraMin = HumanizeDefaults.wordPauseExtraMin
        humanizeWordPauseExtraMax = HumanizeDefaults.wordPauseExtraMax
        humanizeLongPauseChance = HumanizeDefaults.longPauseChance
        humanizeLongPauseMin = HumanizeDefaults.longPauseMin
        humanizeLongPauseMax = HumanizeDefaults.longPauseMax
        humanizeLongPauseCooldownMin = HumanizeDefaults.longPauseCooldownMin
        humanizeLongPauseCooldownMax = HumanizeDefaults.longPauseCooldownMax
        humanizeNewlinePauseMin = HumanizeDefaults.newlinePauseMin
        humanizeNewlinePauseMax = HumanizeDefaults.newlinePauseMax
        humanizeSentencePauseMin = HumanizeDefaults.sentencePauseMin
        humanizeSentencePauseMax = HumanizeDefaults.sentencePauseMax
        humanizeClausePauseMin = HumanizeDefaults.clausePauseMin
        humanizeClausePauseMax = HumanizeDefaults.clausePauseMax
        humanizeRandomPauseChance = HumanizeDefaults.randomPauseChance
        humanizeRandomPauseMin = HumanizeDefaults.randomPauseMin
        humanizeRandomPauseMax = HumanizeDefaults.randomPauseMax
        humanizeMistakeBase = HumanizeDefaults.mistakeBase
        humanizeMistakeSpeedFactor = HumanizeDefaults.mistakeSpeedFactor
        humanizeMistakeBurstBonus = HumanizeDefaults.mistakeBurstBonus
        humanizeMistakeFatigueChance = HumanizeDefaults.mistakeFatigueChance
        humanizeMistakeFatigueBonus = HumanizeDefaults.mistakeFatigueBonus
        humanizeMistakeUppercaseMultiplier = HumanizeDefaults.mistakeUppercaseMultiplier
        humanizeMistakeMaxLower = HumanizeDefaults.mistakeMaxLower
        humanizeMistakeMaxUpper = HumanizeDefaults.mistakeMaxUpper
        humanizeMistakeFixImmediateWeight = HumanizeDefaults.mistakeFixImmediateWeight
        humanizeMistakeFixShortWeight = HumanizeDefaults.mistakeFixShortWeight
        humanizeMistakeFixMediumWeight = HumanizeDefaults.mistakeFixMediumWeight
        humanizeMistakeFixLongWeight = HumanizeDefaults.mistakeFixLongWeight
        humanizeCorrectionPaceMin = HumanizeDefaults.correctionPaceMin
        humanizeCorrectionPaceMax = HumanizeDefaults.correctionPaceMax
        humanizeCorrectionPauseMin = HumanizeDefaults.correctionPauseMin
        humanizeCorrectionPauseMax = HumanizeDefaults.correctionPauseMax
        humanizeCorrectionRetypePauseMin = HumanizeDefaults.correctionRetypePauseMin
        humanizeCorrectionRetypePauseMax = HumanizeDefaults.correctionRetypePauseMax
        humanizeCorrectionMinDelaySeconds = HumanizeDefaults.correctionMinDelaySeconds
        humanizeCorrectionJitterMin = HumanizeDefaults.correctionJitterMin
        humanizeCorrectionJitterMax = HumanizeDefaults.correctionJitterMax
    }

    func randomizeHumanizeSettings() {
        func jitter(_ value: Double, range: ClosedRange<Double>) -> Double {
            let span = range.upperBound - range.lowerBound
            let delta = max(abs(value) * 0.08, span * 0.04)
            return min(max(value + Double.random(in: -delta...delta), range.lowerBound), range.upperBound)
        }

        func jitterInt(_ value: Int, range: ClosedRange<Int>) -> Int {
            let span = range.upperBound - range.lowerBound
            let delta = max(1, Int(round(Double(span) * 0.1)))
            return min(max(value + Int.random(in: -delta...delta), range.lowerBound), range.upperBound)
        }

        humanizeBaseCpsFactor = jitter(humanizeBaseCpsFactor, range: 0.02...0.3)
        var minCps = jitter(humanizeMinCps, range: 0.5...8.0)
        var maxCps = jitter(humanizeMaxCps, range: 4.0...20.0)
        if minCps > maxCps { swap(&minCps, &maxCps) }
        humanizeMinCps = minCps
        humanizeMaxCps = maxCps

        var paceMin = jitter(humanizePaceMin, range: 0.3...1.2)
        var paceMax = jitter(humanizePaceMax, range: 1.0...2.5)
        if paceMin > paceMax { swap(&paceMin, &paceMax) }
        humanizePaceMin = paceMin
        humanizePaceMax = paceMax
        humanizePaceJitter = jitter(humanizePaceJitter, range: 0.0...0.15)

        humanizeBurstChance = jitter(humanizeBurstChance, range: 0.0...0.2)
        var burstMinLen = jitterInt(humanizeBurstMinLen, range: 2...20)
        var burstMaxLen = jitterInt(humanizeBurstMaxLen, range: 4...30)
        if burstMinLen > burstMaxLen { swap(&burstMinLen, &burstMaxLen) }
        humanizeBurstMinLen = burstMinLen
        humanizeBurstMaxLen = burstMaxLen
        var burstMinPace = jitter(humanizeBurstMinPace, range: 0.4...1.2)
        var burstMaxPace = jitter(humanizeBurstMaxPace, range: 0.6...1.6)
        if burstMinPace > burstMaxPace { swap(&burstMinPace, &burstMaxPace) }
        humanizeBurstMinPace = burstMinPace
        humanizeBurstMaxPace = burstMaxPace

        var jitterMin = jitter(humanizeJitterMin, range: 0.2...1.2)
        var jitterMax = jitter(humanizeJitterMax, range: 0.6...2.5)
        if jitterMin > jitterMax { swap(&jitterMin, &jitterMax) }
        humanizeJitterMin = jitterMin
        humanizeJitterMax = jitterMax
        humanizeDelayMinSeconds = jitter(humanizeDelayMinSeconds, range: 0.0...0.2)
        var delayMinFactor = jitter(humanizeDelayMinFactor, range: 0.2...1.5)
        var delayMaxFactor = jitter(humanizeDelayMaxFactor, range: 2.0...10.0)
        if delayMinFactor > delayMaxFactor { swap(&delayMinFactor, &delayMaxFactor) }
        humanizeDelayMinFactor = delayMinFactor
        humanizeDelayMaxFactor = delayMaxFactor
        var delayMinSeconds = humanizeDelayMinSeconds
        var delayMaxSeconds = jitter(humanizeDelayMaxSeconds, range: 0.2...2.0)
        if delayMinSeconds > delayMaxSeconds { swap(&delayMinSeconds, &delayMaxSeconds) }
        humanizeDelayMinSeconds = delayMinSeconds
        humanizeDelayMaxSeconds = delayMaxSeconds

        humanizeWaveAmplitude = jitter(humanizeWaveAmplitude, range: 0.0...0.6)
        var waveMin = jitter(humanizeWaveSpeedMin, range: 0.005...0.08)
        var waveMax = jitter(humanizeWaveSpeedMax, range: 0.02...0.14)
        if waveMin > waveMax { swap(&waveMin, &waveMax) }
        humanizeWaveSpeedMin = waveMin
        humanizeWaveSpeedMax = waveMax
        humanizeWaveSpeedJitter = jitter(humanizeWaveSpeedJitter, range: 0.0...0.02)
        var waveStartMin = jitter(humanizeWaveStartSpeedMin, range: 0.01...0.08)
        var waveStartMax = jitter(humanizeWaveStartSpeedMax, range: 0.02...0.1)
        if waveStartMin > waveStartMax { swap(&waveStartMin, &waveStartMax) }
        humanizeWaveStartSpeedMin = waveStartMin
        humanizeWaveStartSpeedMax = waveStartMax

        var spaceMin = jitter(humanizeSpaceDelayMin, range: 0.0...0.4)
        var spaceMax = jitter(humanizeSpaceDelayMax, range: 0.05...0.6)
        if spaceMin > spaceMax { swap(&spaceMin, &spaceMax) }
        humanizeSpaceDelayMin = spaceMin
        humanizeSpaceDelayMax = spaceMax
        var wordMin = jitterInt(humanizeWordPauseEveryMin, range: 1...10)
        var wordMax = jitterInt(humanizeWordPauseEveryMax, range: 2...16)
        if wordMin > wordMax { swap(&wordMin, &wordMax) }
        humanizeWordPauseEveryMin = wordMin
        humanizeWordPauseEveryMax = wordMax
        var wordExtraMin = jitter(humanizeWordPauseExtraMin, range: 0.0...0.8)
        var wordExtraMax = jitter(humanizeWordPauseExtraMax, range: 0.05...1.2)
        if wordExtraMin > wordExtraMax { swap(&wordExtraMin, &wordExtraMax) }
        humanizeWordPauseExtraMin = wordExtraMin
        humanizeWordPauseExtraMax = wordExtraMax

        humanizeLongPauseChance = jitter(humanizeLongPauseChance, range: 0.0...0.1)
        var longPauseMin = jitter(humanizeLongPauseMin, range: 0.3...2.5)
        var longPauseMax = jitter(humanizeLongPauseMax, range: 0.5...4.0)
        if longPauseMin > longPauseMax { swap(&longPauseMin, &longPauseMax) }
        humanizeLongPauseMin = longPauseMin
        humanizeLongPauseMax = longPauseMax
        var longCooldownMin = jitterInt(humanizeLongPauseCooldownMin, range: 2...20)
        var longCooldownMax = jitterInt(humanizeLongPauseCooldownMax, range: 4...30)
        if longCooldownMin > longCooldownMax { swap(&longCooldownMin, &longCooldownMax) }
        humanizeLongPauseCooldownMin = longCooldownMin
        humanizeLongPauseCooldownMax = longCooldownMax

        var newlineMin = jitter(humanizeNewlinePauseMin, range: 0.1...1.2)
        var newlineMax = jitter(humanizeNewlinePauseMax, range: 0.2...2.0)
        if newlineMin > newlineMax { swap(&newlineMin, &newlineMax) }
        humanizeNewlinePauseMin = newlineMin
        humanizeNewlinePauseMax = newlineMax
        var sentenceMin = jitter(humanizeSentencePauseMin, range: 0.1...1.6)
        var sentenceMax = jitter(humanizeSentencePauseMax, range: 0.2...2.5)
        if sentenceMin > sentenceMax { swap(&sentenceMin, &sentenceMax) }
        humanizeSentencePauseMin = sentenceMin
        humanizeSentencePauseMax = sentenceMax
        var clauseMin = jitter(humanizeClausePauseMin, range: 0.02...0.4)
        var clauseMax = jitter(humanizeClausePauseMax, range: 0.05...0.8)
        if clauseMin > clauseMax { swap(&clauseMin, &clauseMax) }
        humanizeClausePauseMin = clauseMin
        humanizeClausePauseMax = clauseMax
        humanizeRandomPauseChance = jitter(humanizeRandomPauseChance, range: 0.0...0.2)
        var randomMin = jitter(humanizeRandomPauseMin, range: 0.05...1.0)
        var randomMax = jitter(humanizeRandomPauseMax, range: 0.1...1.6)
        if randomMin > randomMax { swap(&randomMin, &randomMax) }
        humanizeRandomPauseMin = randomMin
        humanizeRandomPauseMax = randomMax

        humanizeMistakeBase = jitter(humanizeMistakeBase, range: 0.0...0.03)
        humanizeMistakeSpeedFactor = jitter(humanizeMistakeSpeedFactor, range: 0.0...0.06)
        humanizeMistakeBurstBonus = jitter(humanizeMistakeBurstBonus, range: 0.0...0.02)
        humanizeMistakeFatigueChance = jitter(humanizeMistakeFatigueChance, range: 0.0...0.2)
        humanizeMistakeFatigueBonus = jitter(humanizeMistakeFatigueBonus, range: 0.0...0.02)
        humanizeMistakeUppercaseMultiplier = jitter(humanizeMistakeUppercaseMultiplier, range: 0.2...1.2)
        humanizeMistakeMaxLower = jitter(humanizeMistakeMaxLower, range: 0.01...0.2)
        humanizeMistakeMaxUpper = jitter(humanizeMistakeMaxUpper, range: 0.01...0.2)
        humanizeMistakeFixImmediateWeight = jitter(humanizeMistakeFixImmediateWeight, range: 0.0...5.0)
        humanizeMistakeFixShortWeight = jitter(humanizeMistakeFixShortWeight, range: 0.0...5.0)
        humanizeMistakeFixMediumWeight = jitter(humanizeMistakeFixMediumWeight, range: 0.0...5.0)
        humanizeMistakeFixLongWeight = jitter(humanizeMistakeFixLongWeight, range: 0.0...5.0)
        var correctionPaceMin = jitter(humanizeCorrectionPaceMin, range: 0.4...1.2)
        var correctionPaceMax = jitter(humanizeCorrectionPaceMax, range: 0.6...1.8)
        if correctionPaceMin > correctionPaceMax { swap(&correctionPaceMin, &correctionPaceMax) }
        humanizeCorrectionPaceMin = correctionPaceMin
        humanizeCorrectionPaceMax = correctionPaceMax
        var correctionPauseMin = jitter(humanizeCorrectionPauseMin, range: 0.02...0.4)
        var correctionPauseMax = jitter(humanizeCorrectionPauseMax, range: 0.05...0.6)
        if correctionPauseMin > correctionPauseMax { swap(&correctionPauseMin, &correctionPauseMax) }
        humanizeCorrectionPauseMin = correctionPauseMin
        humanizeCorrectionPauseMax = correctionPauseMax
        var retypeMin = jitter(humanizeCorrectionRetypePauseMin, range: 0.01...0.3)
        var retypeMax = jitter(humanizeCorrectionRetypePauseMax, range: 0.02...0.5)
        if retypeMin > retypeMax { swap(&retypeMin, &retypeMax) }
        humanizeCorrectionRetypePauseMin = retypeMin
        humanizeCorrectionRetypePauseMax = retypeMax
        humanizeCorrectionMinDelaySeconds = jitter(humanizeCorrectionMinDelaySeconds, range: 0.0...0.1)
        var correctionJitterMin = jitter(humanizeCorrectionJitterMin, range: 0.2...1.0)
        var correctionJitterMax = jitter(humanizeCorrectionJitterMax, range: 0.4...1.6)
        if correctionJitterMin > correctionJitterMax { swap(&correctionJitterMin, &correctionJitterMax) }
        humanizeCorrectionJitterMin = correctionJitterMin
        humanizeCorrectionJitterMax = correctionJitterMax
    }
    
    private func saveKeyBinding(_ binding: KeyBinding, key: String) {
        if let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func saveDouble(_ value: Double, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func saveInt(_ value: Int, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private static func loadKeyBinding(key: String, fallback: KeyBinding) -> KeyBinding {
        guard let data = UserDefaults.standard.data(forKey: key),
              let binding = try? JSONDecoder().decode(KeyBinding.self, from: data) else {
            return fallback
        }
        return binding
    }
    
    private static func loadDouble(key: String, fallback: Double) -> Double {
        if let value = UserDefaults.standard.object(forKey: key) as? Double {
            return value
        }
        if let value = UserDefaults.standard.object(forKey: key) as? NSNumber {
            return value.doubleValue
        }
        return fallback
    }
    
    private static func loadInt(key: String, fallback: Int) -> Int {
        if let value = UserDefaults.standard.object(forKey: key) as? Int {
            return value
        }
        if let value = UserDefaults.standard.object(forKey: key) as? NSNumber {
            return value.intValue
        }
        return fallback
    }
}
