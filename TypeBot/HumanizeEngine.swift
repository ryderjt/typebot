import Foundation

/// HumanizeEngine rewrites robot-sounding text into warmer, more varied phrasing.
/// It uses a multi-phase pipeline: whitespace cleanup, sentence carving, tone softening,
/// cadence shaping, and connective tissue injection. A seeded RNG keeps output stable
/// for the same input.
struct HumanizeEngine {
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x123456789ABCDEF : seed }
        mutating func next() -> UInt64 {
            state &*= 0x5851F42D4C957F2D
            state &+= 0x14057B7EF767814F
            return state
        }
    }

    func humanize(_ attributed: NSAttributedString) -> NSAttributedString {
        guard attributed.length > 0 else { return attributed }
        let baseAttributes = baseAttributes(from: attributed)
        var generator = SeededGenerator(seed: seed(from: attributed.string))
        let normalized = normalizeWhitespace(in: attributed.string)
        let paragraphs = splitParagraphs(normalized)
        let rewrittenParagraphs = paragraphs.map { paragraph in
            rewrite(paragraph: paragraph, generator: &generator)
        }
        let output = rewrittenParagraphs.joined(separator: "\n\n")
        let styled = NSMutableAttributedString(string: output)
        if !baseAttributes.isEmpty {
            styled.addAttributes(baseAttributes, range: NSRange(location: 0, length: styled.length))
        }
        return styled
    }

    private func baseAttributes(from attributed: NSAttributedString) -> [NSAttributedString.Key: Any] {
        guard attributed.length > 0 else { return [:] }
        return attributed.attributes(at: 0, effectiveRange: nil)
    }

    private func seed(from text: String) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(text)
        let raw = hasher.finalize()
        return UInt64(bitPattern: Int64(raw))
    }

    private func normalizeWhitespace(in text: String) -> String {
        let collapsedSpaces = text
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        return collapsedSpaces.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitParagraphs(_ text: String) -> [String] {
        let raw = text.components(separatedBy: "\n\n")
        return raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func rewrite(paragraph: String, generator: inout SeededGenerator) -> String {
        let sentences = splitIntoSentences(paragraph)
        guard !sentences.isEmpty else { return paragraph }
        var rewritten: [String] = []
        let connectors = ["And then", "From there", "In practice", "The short version", "Meanwhile"]
        for (index, sentence) in sentences.enumerated() {
            var text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            text = applyLexicalWarmup(to: text)
            text = softenAbsolutes(in: text)
            text = reshapeCadence(of: text, generator: &generator)
            if index == 0, let intro = pickIntro(generator: &generator) {
                text = intro + " " + lowercaseFirst(text)
            } else if index > 0, Double.random(in: 0...1, using: &generator) < 0.35 {
                let connector = pick(from: connectors, generator: &generator)
                text = connector + ", " + lowercaseFirst(text)
            }
            if index == sentences.count - 1 {
                text = closeWarmly(text, generator: &generator)
            }
            rewritten.append(ensureTerminalPunctuation(for: text))
        }
        return rewritten.joined(separator: " ")
    }

    private func splitIntoSentences(_ paragraph: String) -> [String] {
        var results: [String] = []
        var current = ""
        for char in paragraph {
            current.append(char)
            if ".!?".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { results.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            results.append(tail)
        }
        return results
    }

    private func applyLexicalWarmup(to sentence: String) -> String {
        let swaps: [(String, String)] = [
            ("utilize", "use"),
            ("leverage", "make the most of"),
            ("in order to", "to"),
            ("ensure", "make sure"),
            ("synergy", "working together"),
            ("optimize", "tune"),
            ("robust", "solid"),
            ("prioritize", "keep front and center"),
            ("proactively", "ahead of time"),
            ("demonstrate", "show"),
            ("execute", "pull off"),
            ("enable", "let")
        ]
        var output = sentence
        for (needle, replacement) in swaps {
            output = output.replacingOccurrences(of: needle, with: replacement, options: [.caseInsensitive, .regularExpression])
        }
        return output
    }

    private func softenAbsolutes(in sentence: String) -> String {
        let softenings: [(String, String)] = [
            ("always", "usually"),
            ("never", "hardly ever"),
            ("must", "should probably"),
            ("impossible", "unlikely"),
            ("obviously", "to be honest"),
            ("clearly", "it seems clear"),
            ("perfect", "pretty close to perfect")
        ]
        var output = sentence
        for (needle, replacement) in softenings {
            output = output.replacingOccurrences(of: "\\b\(needle)\\b", with: replacement, options: [.caseInsensitive, .regularExpression])
        }
        return output
    }

    private func reshapeCadence(of sentence: String, generator: inout SeededGenerator) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 80 else { return trimmed }
        let breakpoints = [", ", "; ", ": ", " and ", " but "]
        for point in breakpoints {
            if let range = trimmed.range(of: point, options: .caseInsensitive, range: trimmed.index(trimmed.startIndex, offsetBy: trimmed.count / 3)..<trimmed.endIndex, locale: nil) {
                if Double.random(in: 0...1, using: &generator) < 0.7 {
                    let left = String(trimmed[..<range.upperBound])
                    let right = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    return left + " almost like a quick aside, " + lowercaseFirst(right)
                }
            }
        }
        return trimmed
    }

    private func closeWarmly(_ sentence: String, generator: inout SeededGenerator) -> String {
        guard sentence.count > 60 else { return sentence }
        let codas = [
            "if you want the short version.",
            "and that is really the heart of it.",
            "so it feels like an actual person wrote it.",
            "which is the part that matters to readers.",
            "and that keeps it sounding human."
        ]
        if Double.random(in: 0...1, using: &generator) < 0.45 {
            let coda = pick(from: codas, generator: &generator)
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let withoutPunctuation = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            return withoutPunctuation + ", " + coda
        }
        return sentence
    }

    private func ensureTerminalPunctuation(for sentence: String) -> String {
        guard let last = sentence.trimmingCharacters(in: .whitespacesAndNewlines).last else { return sentence }
        if ".!?".contains(last) {
            return sentence
        }
        return sentence + "."
    }

    private func pickIntro(generator: inout SeededGenerator) -> String? {
        let intros = [
            "In plain language,",
            "If we put it simply,",
            "Stepping back for a second,",
            "Here is the human-friendly take,",
            "Let me phrase it like a person,"
        ]
        return Double.random(in: 0...1, using: &generator) < 0.65 ? pick(from: intros, generator: &generator) : nil
    }

    private func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        let lowered = String(first).lowercased()
        let tail = text.dropFirst()
        return lowered + tail
    }

    private func pick<T>(from array: [T], generator: inout SeededGenerator) -> T {
        let index = Int.random(in: 0..<array.count, using: &generator)
        return array[index]
    }
}
