import SwiftUI
import AppKit
import RepriseCore

/// The editor. AppKit TextKit 2 under the hood: layout is viewport-based, so a 5 MB prompt
/// scrolls like a 5 KB one. Syntax highlighting is incremental — only the edited paragraphs
/// are re-styled on each keystroke; a full pass only happens when a code fence opens/closes.
struct MarkdownEditor: NSViewRepresentable {
    let promptID: ID
    let initialText: String
    var font: EditorFont
    var fontSize: CGFloat
    var inset: CGFloat
    var measure: CGFloat
    var onChange: (String) -> Void
    var onPasteImage: (Data, String) -> Void
    var onDropFiles: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 60, right: 0)

        let tv = PromptTextView(usingTextLayoutManager: true)
        tv.coordinator = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = false
        tv.leftInset = inset
        tv.measure = measure
        tv.textContainerInset = NSSize(width: 0, height: 6)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.lineFragmentPadding = 0
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.insertionPointColor = Folio.nsRubric
        tv.selectedTextAttributes = [.backgroundColor: Folio.nsSelection]

        let c = context.coordinator
        c.textView = tv
        c.highlighter = Highlighter(font: font, size: fontSize)
        tv.typingAttributes = c.highlighter.base
        tv.textStorage?.delegate = c
        tv.string = initialText
        c.highlighter.fullPass(tv.textStorage!)
        tv.delegate = c

        scroll.documentView = tv
        DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        guard let tv = c.textView else { return }
        if tv.measure != measure || tv.leftInset != inset {
            tv.measure = measure; tv.leftInset = inset; tv.relayoutMeasure()
        }
        if c.highlighter.needsRebuild(font: font, size: fontSize) {
            c.highlighter = Highlighter(font: font, size: fontSize)
            tv.typingAttributes = c.highlighter.base
            c.highlighter.fullPass(tv.textStorage!)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownEditor
        weak var textView: PromptTextView?
        var highlighter: Highlighter!

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.onChange(tv.string)
        }

        func textStorage(_ storage: NSTextStorage, didProcessEditing mask: NSTextStorageEditActions, range: NSRange, changeInLength delta: Int) {
            guard mask.contains(.editedCharacters) else { return }
            highlighter.incremental(storage, edited: range)
        }
    }
}

final class PromptTextView: NSTextView {
    weak var coordinator: MarkdownEditor.Coordinator?
    /// The text sits at a book measure, left-aligned to the page's inset, not stretched across the window.
    var leftInset: CGFloat = 44
    var measure: CGFloat = 660

    override var textContainerOrigin: NSPoint {
        NSPoint(x: leftInset, y: textContainerInset.height)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        relayoutMeasure()
    }

    func relayoutMeasure() {
        let w = max(120, min(measure, bounds.width - leftInset - 28))
        if let tc = textContainer, abs(tc.size.width - w) > 0.5 {
            tc.size = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        // Files (e.g. screenshots dragged from Finder and copied) → attachments.
        if pb.types?.contains(.fileURL) == true,
           let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            coordinator?.parent.onDropFiles(urls)
            return
        }
        // Raw image data (⌃⇧⌘4 screenshot to clipboard) → image attachment.
        if pb.string(forType: .string) == nil {
            if let png = pb.data(forType: .png) { coordinator?.parent.onPasteImage(png, "png"); return }
            if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                coordinator?.parent.onPasteImage(png, "png"); return
            }
        }
        pasteAsPlainText(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            coordinator?.parent.onDropFiles(urls)
            return true
        }
        return super.performDragOperation(sender)
    }

    /// Tab inside a list indents; ⌘↩ is handled by the app's menu ("Use").
    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }
}

/// Markdown + prompt-engineering aware highlighter, in the edition's inks.
/// Structure is carried by weight and slate; rubric is reserved for blanks, the things you fill in.
final class Highlighter {
    let base: [NSAttributedString.Key: Any]
    private let fontKind: EditorFont
    private let size: CGFloat
    private let mono: NSFont
    private let monoStrong: NSFont
    private let bodyFont: NSFont
    private let boldFont: NSFont
    private let italicFont: NSFont
    private let text = Folio.nsInk
    private let secondary = Folio.nsSlate
    private let tertiary = Folio.nsAsh
    private let rubric = Folio.nsRubric
    private let codeBG = Folio.nsWash
    private var fences: [NSRange] = []

    private static let rx: (String) -> NSRegularExpression = { try! NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) }
    private static let heading = rx(#"^(#{1,6})[ \t]+.*$"#)
    private static let bold = rx(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let italic = rx(#"(?<![\*\w])(\*|_)(?=\S)([^\*_\n]+?)(?<=\S)\1(?![\*\w])"#)
    private static let code = rx(#"`[^`\n]+`"#)
    private static let list = rx(#"^[ \t]*([-*+]|\d+[.)])[ \t]+"#)
    private static let checkbox = rx(#"^[ \t]*[-*+][ \t]+\[[ xX]\]"#)
    private static let quote = rx(#"^>.*$"#)
    private static let link = rx(#"\[([^\]\n]+)\]\(([^)\s]+)\)|https?://[^\s<>)\]]+"#)
    private static let xmlTag = rx(#"</?[A-Za-z][\w\-]*(?:\s[^<>\n]*)?/?>"#)
    private static let rule = rx(#"^[ \t]*([-*_])([ \t]*\1){2,}[ \t]*$"#)

    init(font: EditorFont, size: CGFloat) {
        self.fontKind = font
        self.size = size
        bodyFont = font.nsFont(size: size)
        boldFont = font.nsFont(size: size, weight: .semibold)
        italicFont = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
        mono = .monospacedSystemFont(ofSize: size * 0.84, weight: .regular)
        monoStrong = .monospacedSystemFont(ofSize: size * 0.84, weight: .semibold)
        let para = NSMutableParagraphStyle()
        para.lineHeightMultiple = font == .mono ? 1.3 : Folio.style.lineHeight
        para.paragraphSpacing = size * 0.45
        base = [.font: bodyFont, .foregroundColor: text, .paragraphStyle: para]
    }

    func needsRebuild(font: EditorFont, size: CGFloat) -> Bool {
        font != fontKind || size != self.size
    }

    /// Huge documents are painted in paragraph-aligned chunks across run-loop turns,
    /// so opening a multi-megabyte prompt never blocks the UI.
    func fullPass(_ s: NSTextStorage) {
        fences = Highlighter.findFences(s.string as NSString)
        let chunk = 60_000
        guard s.length > chunk * 2 else {
            s.beginEditing(); paint(s, in: NSRange(location: 0, length: s.length)); s.endEditing()
            return
        }
        func step(_ start: Int) {
            guard start < s.length else { return }
            let ns = s.string as NSString
            let end = NSMaxRange(ns.paragraphRange(for: NSRange(location: min(start + chunk, s.length - 1), length: 0)))
            s.beginEditing(); paint(s, in: NSRange(location: start, length: end - start)); s.endEditing()
            DispatchQueue.main.async { [weak self, weak s] in
                guard self != nil, let s else { return }
                _ = s
                step(end)
            }
        }
        step(0)
    }

    func incremental(_ s: NSTextStorage, edited: NSRange) {
        let ns = s.string as NSString
        let newFences = Highlighter.findFences(ns)
        if newFences != fences {
            fences = newFences
            paint(s, in: NSRange(location: 0, length: s.length))
            return
        }
        // Re-style just the touched paragraphs (+1 neighbour to catch multi-line constructs).
        var r = ns.paragraphRange(for: edited)
        if r.location > 0 { r = NSUnionRange(r, ns.paragraphRange(for: NSRange(location: r.location - 1, length: 0))) }
        if NSMaxRange(r) < ns.length { r = NSUnionRange(r, ns.paragraphRange(for: NSRange(location: NSMaxRange(r), length: 0))) }
        paint(s, in: r)
    }

    static func findFences(_ ns: NSString) -> [NSRange] {
        var out: [NSRange] = []
        var search = NSRange(location: 0, length: ns.length)
        var open: Int?
        while true {
            let r = ns.range(of: "```", options: [], range: search)
            if r.location == NSNotFound { break }
            let lineStart = ns.lineRange(for: NSRange(location: r.location, length: 0)).location
            let prefix = ns.substring(with: NSRange(location: lineStart, length: r.location - lineStart))
            if prefix.trimmingCharacters(in: .whitespaces).isEmpty {
                if let o = open {
                    let end = NSMaxRange(ns.lineRange(for: r))
                    out.append(NSRange(location: o, length: end - o))
                    open = nil
                } else {
                    open = lineStart
                }
            }
            let next = NSMaxRange(r)
            search = NSRange(location: next, length: ns.length - next)
        }
        if let o = open { out.append(NSRange(location: o, length: ns.length - o)) }
        return out
    }

    private func paint(_ s: NSTextStorage, in range: NSRange) {
        guard range.length > 0 else { return }
        let ns = s.string as NSString
        s.setAttributes(base, range: range)

        func each(_ re: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            re.enumerateMatches(in: s.string, options: [], range: range) { m, _, _ in if let m { body(m) } }
        }

        each(Highlighter.heading) { m in
            let level = m.range(at: 1).length
            let scale: CGFloat = [1.4, 1.22, 1.1, 1.0, 1.0, 1.0][min(level, 6) - 1]
            s.addAttributes([.font: fontKind.nsFont(size: size * scale, weight: .semibold)], range: m.range)
            s.addAttribute(.foregroundColor, value: tertiary, range: m.range(at: 1))
        }
        each(Highlighter.rule) { m in s.addAttribute(.foregroundColor, value: tertiary, range: m.range) }
        each(Highlighter.quote) { m in
            s.addAttributes([.foregroundColor: secondary, .font: italicFont], range: m.range)
        }
        each(Highlighter.list) { m in s.addAttributes([.foregroundColor: secondary], range: m.range(at: 1)) }
        each(Highlighter.checkbox) { m in s.addAttribute(.foregroundColor, value: secondary, range: m.range) }
        each(Highlighter.bold) { m in
            s.addAttribute(.font, value: boldFont, range: m.range)
            let d = m.range(at: 1).length
            s.addAttribute(.foregroundColor, value: tertiary, range: NSRange(location: m.range.location, length: d))
            s.addAttribute(.foregroundColor, value: tertiary, range: NSRange(location: NSMaxRange(m.range) - d, length: d))
        }
        each(Highlighter.italic) { m in s.addAttribute(.font, value: italicFont, range: m.range) }
        each(Highlighter.xmlTag) { m in
            s.addAttributes([.foregroundColor: secondary, .font: mono], range: m.range)
        }
        each(Highlighter.link) { m in
            s.addAttributes([.foregroundColor: secondary, .underlineStyle: NSUnderlineStyle.single.rawValue,
                             .underlineColor: tertiary], range: m.range)
        }
        each(Highlighter.code) { m in
            s.addAttributes([.font: mono, .backgroundColor: codeBG], range: m.range)
        }

        // Fenced code blocks.
        for f in fences where NSIntersectionRange(f, range).length > 0 {
            let r = NSIntersectionRange(f, range)
            s.addAttributes([.font: mono, .backgroundColor: codeBG, .foregroundColor: text], range: r)
        }

        // Template placeholders — painted last so they win.
        let localStart = range.location
        let local = ns.substring(with: range)
        if local.contains("{{") {
            for p in Template.placeholderRanges(in: local) {
                let r = NSRange(location: p.location + localStart, length: p.length)
                let inner = ns.substring(with: r)
                let isInclude = inner.hasPrefix("{{>") || inner.hasPrefix("{{ >")
                let isBuiltin = inner.contains("{{@") || inner.contains("{{ @")
                if isInclude {
                    s.addAttributes([.foregroundColor: secondary, .font: monoStrong,
                                     .underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: tertiary], range: r)
                } else if isBuiltin {
                    s.addAttributes([.foregroundColor: secondary, .font: monoStrong], range: r)
                } else {
                    s.addAttributes([.foregroundColor: rubric, .font: monoStrong,
                                     .underlineStyle: NSUnderlineStyle.single.rawValue,
                                     .underlineColor: Folio.nsAccentSoft], range: r)
                }
            }
        }
    }
}
