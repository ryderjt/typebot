import SwiftUI
import AppKit
import Combine

final class RichTextController: ObservableObject {
    weak var textView: NSTextView?
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var isStrikethrough = false
    @Published var alignment: NSTextAlignment = .left
    @Published var fontName: String = NSFont.systemFont(ofSize: 15).fontName
    @Published var fontSize: CGFloat = 15
    @Published var lineHeightMultiple: CGFloat = 1.18
    @Published var paragraphSpacing: CGFloat = 6
    
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
    
    func applyFont(named name: String) {
        applyFontTransform { current in
            NSFont(name: name, size: current.pointSize) ?? current
        }
        refreshFormattingState()
    }
    
    func setFontSize(_ size: CGFloat) {
        applyFontTransform { NSFontManager.shared.convert($0, toSize: size) }
        refreshFormattingState()
    }
    
    func adjustFontSize(by delta: CGFloat) {
        setFontSize(max(8, fontSize + delta))
    }
    
    func setAlignment(_ newAlignment: NSTextAlignment) {
        applyParagraphStyle { style in
            style.alignment = newAlignment
        }
        refreshFormattingState()
    }
    
    func setLineHeight(_ multiple: CGFloat) {
        applyParagraphStyle { style in
            style.lineHeightMultiple = multiple
        }
        refreshFormattingState()
    }
    
    func setParagraphSpacing(_ spacing: CGFloat) {
        applyParagraphStyle { style in
            style.paragraphSpacing = spacing
        }
        refreshFormattingState()
    }
    
    func clearFormatting() {
        guard let textView else { return }
        let cleaned = NSMutableAttributedString(string: textView.string)
        let baseColor = textView.textColor ?? NSColor.labelColor
        let baseFont = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineHeightMultiple = 1.18
        defaultParagraph.paragraphSpacing = 6
        cleaned.addAttributes([
            .foregroundColor: baseColor,
            .font: baseFont,
            .paragraphStyle: defaultParagraph
        ], range: NSRange(location: 0, length: cleaned.length))
        textView.textStorage?.setAttributedString(cleaned)
        textView.typingAttributes = [
            .foregroundColor: baseColor,
            .font: baseFont,
            .paragraphStyle: defaultParagraph
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
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        let alignmentValue = paragraphStyle?.alignment ?? .natural
        alignment = alignmentValue == .natural ? .left : alignmentValue
        lineHeightMultiple = paragraphStyle?.lineHeightMultiple ?? 1.18
        paragraphSpacing = paragraphStyle?.paragraphSpacing ?? 6
        fontName = font.fontName
        fontSize = font.pointSize
    }
    
    private func applyFontTransform(_ transform: (NSFont) -> NSFont) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let manager = NSFontManager.shared

        if selection.length == 0 {
            var attrs = textView.typingAttributes
            let baseFont = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            var updated = transform(baseFont)
            updated = manager.convert(updated, toHaveTrait: manager.traits(of: baseFont))
            attrs[.font] = updated
            textView.typingAttributes = attrs
            return
        }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selection, options: []) { value, range, _ in
            let baseFont = (value as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let traits = manager.traits(of: baseFont)
            var updated = transform(baseFont)
            updated = manager.convert(updated, toHaveTrait: traits)
            textStorage.addAttribute(.font, value: updated, range: range)
        }
        textStorage.endEditing()
    }
    
    private func applyParagraphStyle(_ apply: (NSMutableParagraphStyle) -> Void) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let baseStyle = NSMutableParagraphStyle()
        baseStyle.lineHeightMultiple = lineHeightMultiple
        baseStyle.paragraphSpacing = paragraphSpacing
        baseStyle.alignment = alignment
        
        if selection.length == 0 {
            var attrs = textView.typingAttributes
            let style = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? baseStyle
            apply(style)
            attrs[.paragraphStyle] = style
            textView.typingAttributes = attrs
            return
        }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.paragraphStyle, in: selection, options: []) { value, range, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? baseStyle
            apply(style)
            textStorage.addAttribute(.paragraphStyle, value: style, range: range)
        }
        textStorage.endEditing()
    }
    
    private func applyAttribute(_ key: NSAttributedString.Key, value: Any) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        if selection.length == 0 {
            var attrs = textView.typingAttributes
            attrs[key] = value
            textView.typingAttributes = attrs
            return
        }
        textStorage.beginEditing()
        textStorage.addAttribute(key, value: value, range: selection)
        textStorage.endEditing()
    }
}

final class TypeBotTextView: NSTextView {
    var defaultTextColor: NSColor = .labelColor
    var defaultFont: NSFont = .systemFont(ofSize: 15)
    
    func applyDefaults() {
        if typingAttributes[.foregroundColor] == nil {
            typingAttributes[.foregroundColor] = defaultTextColor
        }
        if typingAttributes[.font] == nil {
            typingAttributes[.font] = defaultFont
        }
        if typingAttributes[.paragraphStyle] == nil {
            let style = NSMutableParagraphStyle()
            style.alignment = .left
            style.lineHeightMultiple = 1.18
            style.paragraphSpacing = 6
            typingAttributes[.paragraphStyle] = style
        }
    }
    
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        applyDefaults()
        super.insertText(insertString, replacementRange: replacementRange)
    }
    
    override func didChangeText() {
        super.didChangeText()
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        applyDefaults()
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
        textView.defaultTextColor = color
        textView.defaultFont = font
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.textStorage?.setAttributedString(text)
        textView.applyDefaults()
        
        context.coordinator.lastSyncedText = text

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
        if context.coordinator.lastSyncedText.isEqual(to: text) == false {
            context.coordinator.isProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(text)
            context.coordinator.lastSyncedText = text
            context.coordinator.isProgrammaticUpdate = false
        }
        let color = NSColor.labelColor
        textView.textColor = color
        textView.insertionPointColor = color
        if let typedView = textView as? TypeBotTextView {
            typedView.defaultTextColor = color
            typedView.defaultFont = textView.font ?? NSFont.systemFont(ofSize: 15)
            typedView.applyDefaults()
        } else {
            textView.typingAttributes[.foregroundColor] = color
        }
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        @Binding var text: NSAttributedString
        weak var controller: RichTextController?
        var isProgrammaticUpdate = false
        var lastSyncedText: NSAttributedString
        
        init(text: Binding<NSAttributedString>, controller: RichTextController) {
            _text = text
            self.controller = controller
            self.lastSyncedText = text.wrappedValue
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard isProgrammaticUpdate == false else { return }
            let updated = NSAttributedString(attributedString: textView.attributedString())
            if text.isEqual(to: updated) == false {
                text = updated
            }
            lastSyncedText = updated
            controller?.refreshFormattingState()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard notification.object is NSTextView else { return }
            guard isProgrammaticUpdate == false else { return }
            controller?.refreshFormattingState()
        }

        func textStorageDidProcessEditing(
            _ textStorage: NSTextStorage,
            edited editMask: NSTextStorageEditActions,
            range _: NSRange,
            changeInLength _: Int,
            invalidatedRange _: NSRange
        ) {
            guard isProgrammaticUpdate == false else { return }
            guard editMask.contains(.editedCharacters) || editMask.contains(.editedAttributes) else { return }
            let updated = NSAttributedString(attributedString: textStorage)
            if text.isEqual(to: updated) == false {
                text = updated
            }
            lastSyncedText = updated
            controller?.refreshFormattingState()
        }
    }
}
