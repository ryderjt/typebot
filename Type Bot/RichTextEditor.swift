import SwiftUI
import AppKit
import Combine

final class RichTextController: ObservableObject {
    weak var textView: NSTextView?
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var isStrikethrough = false
    
    func toggleBold() {
        toggleFontTrait(.boldFontMask)
        refreshFormattingState()
    }
    
    func toggleItalic() {
        toggleFontTrait(.italicFontMask)
        refreshFormattingState()
    }
    
    func toggleUnderline() {
        toggleAttribute(.underlineStyle, onValue: NSUnderlineStyle.single.rawValue)
        refreshFormattingState()
    }
    
    func toggleStrikethrough() {
        toggleAttribute(.strikethroughStyle, onValue: NSUnderlineStyle.single.rawValue)
        refreshFormattingState()
    }
    
    func clearFormatting() {
        guard let textView else { return }
        let cleaned = NSMutableAttributedString(string: textView.string)
        let baseColor = textView.textColor ?? NSColor.labelColor
        cleaned.addAttribute(.foregroundColor, value: baseColor, range: NSRange(location: 0, length: cleaned.length))
        textView.textStorage?.setAttributedString(cleaned)
        textView.typingAttributes = [
            .foregroundColor: baseColor,
            .font: textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]
        refreshFormattingState()
    }

    func refreshFormattingState() {
        guard let textView else { return }
        updateFormattingState(from: textView)
    }
    
    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let manager = NSFontManager.shared
        
        if selection.length == 0 {
            var attrs = textView.typingAttributes
            let font = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let hasTrait = manager.traits(of: font).contains(trait)
            let updatedFont = hasTrait ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            attrs[.font] = updatedFont
            textView.typingAttributes = attrs
            return
        }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selection, options: []) { value, range, _ in
            let font = (value as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let hasTrait = manager.traits(of: font).contains(trait)
            let updatedFont = hasTrait ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            textStorage.addAttribute(.font, value: updatedFont, range: range)
        }
        textStorage.endEditing()
    }
    
    private func toggleAttribute(_ key: NSAttributedString.Key, onValue: Int) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        
        if selection.length == 0 {
            var attrs = textView.typingAttributes
            let current = (attrs[key] as? Int) ?? 0
            attrs[key] = current == 0 ? onValue : 0
            textView.typingAttributes = attrs
            return
        }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(key, in: selection, options: []) { value, range, _ in
            let current = value as? Int ?? 0
            textStorage.addAttribute(key, value: current == 0 ? onValue : 0, range: range)
        }
        textStorage.endEditing()
    }

    private func updateFormattingState(from textView: NSTextView) {
        let selection = textView.selectedRange()
        let attrs: [NSAttributedString.Key: Any]
        if selection.length > 0, let textStorage = textView.textStorage, selection.location < textStorage.length {
            attrs = textStorage.attributes(at: selection.location, effectiveRange: nil)
        } else {
            attrs = textView.typingAttributes
        }
        let font = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let traits = NSFontManager.shared.traits(of: font)
        isBold = traits.contains(.boldFontMask)
        isItalic = traits.contains(.italicFontMask)
        isUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0
        isStrikethrough = (attrs[.strikethroughStyle] as? Int ?? 0) != 0
    }
}

final class TypeBotTextView: NSTextView {
    var forcedTextColor: NSColor = .white
    var forcedFont: NSFont = .systemFont(ofSize: 15)
    
    func applyDefaults() {
        typingAttributes[.foregroundColor] = forcedTextColor
        if typingAttributes[.font] == nil {
            typingAttributes[.font] = forcedFont
        }
    }
    
    func enforceVisibleColor() {
        guard let textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        if fullRange.length == 0 { return }
        textStorage.addAttribute(.foregroundColor, value: forcedTextColor, range: fullRange)
    }
    
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        applyDefaults()
        super.insertText(insertString, replacementRange: replacementRange)
    }
    
    override func didChangeText() {
        super.didChangeText()
        enforceVisibleColor()
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        applyDefaults()
        enforceVisibleColor()
        return result
    }
}

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    @ObservedObject var controller: RichTextController
    var isDarkMode: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, controller: controller)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = TypeBotTextView(frame: .zero)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.drawsBackground = false
        textView.importsGraphics = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        let font = NSFont.systemFont(ofSize: 15)
        let color = NSColor.labelColor
        textView.textColor = color
        textView.insertionPointColor = color
        textView.font = font
        textView.forcedTextColor = color
        textView.forcedFont = font
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(text)
        textView.applyDefaults()
        textView.enforceVisibleColor()
        
        controller.textView = textView
        DispatchQueue.main.async { [weak controller] in
            controller?.refreshFormattingState()
        }
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.attributedString() != text {
            textView.textStorage?.setAttributedString(text)
        }
        let color = NSColor.labelColor
        textView.textColor = color
        textView.insertionPointColor = color
        if let typedView = textView as? TypeBotTextView {
            typedView.forcedTextColor = color
            typedView.forcedFont = textView.font ?? NSFont.systemFont(ofSize: 15)
            typedView.applyDefaults()
            typedView.enforceVisibleColor()
        } else {
            textView.typingAttributes[.foregroundColor] = color
        }
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: NSAttributedString
        weak var controller: RichTextController?
        
        init(text: Binding<NSAttributedString>, controller: RichTextController) {
            _text = text
            self.controller = controller
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if let typedView = textView as? TypeBotTextView {
                typedView.enforceVisibleColor()
            }
            let output = NSMutableAttributedString(attributedString: textView.attributedString())
            let color = (textView as? TypeBotTextView)?.forcedTextColor ?? textView.textColor ?? NSColor.labelColor
            if output.length > 0 {
                output.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: output.length))
            }
            text = output
            controller?.refreshFormattingState()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard notification.object is NSTextView else { return }
            controller?.refreshFormattingState()
        }
    }
}
