import Foundation

/// Reprise template language — small on purpose, readable as plain text.
///
///     {{file}}                      variable
///     {{language = Swift}}          variable with default
///     {{tone: terse | friendly}}    choice (first option is the default)
///     {{@date}} {{@time}} {{@clipboard}} {{@uuid}}   built-ins
///     {{> Staff Engineer Role}}     include another prompt by name (composition)
///     \{{literal}}                  escape
public enum Template {
    public struct Variable: Hashable, Sendable, Identifiable {
        public var name: String
        public var defaultValue: String
        public var options: [String]
        public var id: String { name }
        public var isChoice: Bool { !options.isEmpty }
    }

    public enum Token: Hashable, Sendable {
        case text(String)
        case variable(Variable)
        case builtin(String)
        case include(String)
    }

    public static let builtins = ["date", "time", "datetime", "clipboard", "uuid", "weekday"]

    /// Single linear scan over UTF-16 using memchr-speed `range(of:)` — fast on multi-MB prompts.
    /// `visit` receives (placeholderRange, token) and returns false to stop early.
    static func scan(_ ns: NSString, _ visit: (NSRange, Token) -> Bool) {
        let len = ns.length
        var search = 0
        var memo: [String: Token?] = [:]   // big prompts repeat the same placeholders
        while search < len - 3 {
            let open = ns.range(of: "{{", options: .literal, range: NSRange(location: search, length: len - search))
            if open.location == NSNotFound { return }
            if open.location > 0 && ns.character(at: open.location - 1) == 0x5C { search = open.location + 2; continue }
            let from = open.location + 2
            let close = ns.range(of: "}}", options: .literal, range: NSRange(location: from, length: min(len - from, 200)))
            var parsed: Token? = nil
            if close.location != NSNotFound {
                let inner = ns.substring(with: NSRange(location: from, length: close.location - from))
                if let m = memo[inner] { parsed = m } else { parsed = parsePlaceholder(inner); memo[inner] = parsed }
            }
            if let t = parsed {
                if !visit(NSRange(location: open.location, length: close.location + 2 - open.location), t) { return }
                search = close.location + 2
            } else {
                search = open.location + 1
            }
        }
    }

    /// Ranges of every `{{…}}` placeholder (used by the editor to paint them).
    public static func placeholderRanges(in s: String) -> [NSRange] {
        var out: [NSRange] = []
        scan(s as NSString) { r, _ in out.append(r); return true }
        return out
    }

    public static func hasPlaceholders(_ s: String) -> Bool {
        var found = false
        scan(s as NSString) { _, _ in found = true; return false }
        return found
    }

    static func parsePlaceholder(_ raw: String) -> Token? {
        let inner = raw.trimmingCharacters(in: .whitespaces)
        guard !inner.isEmpty, inner.count <= 160, !inner.contains("\n"), !inner.contains("{"), !inner.contains("}") else { return nil }
        if inner.hasPrefix(">") {
            let name = inner.dropFirst().trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : .include(name)
        }
        if inner.hasPrefix("@") {
            let name = inner.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
            return builtins.contains(name) ? .builtin(name) : nil
        }
        var name = inner
        var def = ""
        var options: [String] = []
        if let eq = inner.firstIndex(of: "=") {
            name = String(inner[..<eq]).trimmingCharacters(in: .whitespaces)
            def = String(inner[inner.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        } else if let colon = inner.firstIndex(of: ":") {
            name = String(inner[..<colon]).trimmingCharacters(in: .whitespaces)
            options = inner[inner.index(after: colon)...]
                .split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            // A real choice lists 2+ options; this keeps code like style={{ color: 'red' }} literal.
            guard options.count >= 2 else { return nil }
            def = options.first ?? ""
        }
        guard isValidName(name) else { return nil }
        return .variable(Variable(name: name, defaultValue: def, options: options))
    }

    private static let nameChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- ."))

    static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 48, let first = name.unicodeScalars.first,
              CharacterSet.letters.contains(first) || first == "_" else { return false }
        return name.unicodeScalars.allSatisfy { nameChars.contains($0) }
    }

    public static func tokenize(_ s: String) -> [Token] {
        let ns = s as NSString
        var tokens: [Token] = []
        var cursor = 0
        func text(upTo end: Int) {
            guard end > cursor else { return }
            // Unescape \{{ in plain text runs.
            let chunk = ns.substring(with: NSRange(location: cursor, length: end - cursor))
            tokens.append(.text(chunk.contains("\\{{") ? chunk.replacingOccurrences(of: "\\{{", with: "{{") : chunk))
        }
        scan(ns) { r, t in
            text(upTo: r.location)
            tokens.append(t)
            cursor = NSMaxRange(r)
            return true
        }
        text(upTo: ns.length)
        return tokens
    }

    /// Unique variables in order of first appearance, following includes.
    public static func variables(in s: String, resolve: ((String) -> String?)? = nil, depth: Int = 0) -> [Variable] {
        var seen = Set<String>()
        var out: [Variable] = []
        for t in tokenize(s) {
            switch t {
            case .variable(let v):
                if seen.insert(v.name).inserted { out.append(v) }
                else if let i = out.firstIndex(where: { $0.name == v.name }), out[i].defaultValue.isEmpty, out[i].options.isEmpty {
                    out[i] = v // a later occurrence may carry the default/options
                }
            case .include(let name):
                guard depth < 8, let body = resolve?(name) else { continue }
                for v in variables(in: body, resolve: resolve, depth: depth + 1) where seen.insert(v.name).inserted {
                    out.append(v)
                }
            default: break
            }
        }
        return out
    }

    public struct Context {
        public var values: [String: String]
        public var clipboard: () -> String
        public var resolve: (String) -> String?
        public var now: Date

        public init(values: [String: String] = [:], clipboard: @escaping () -> String = { "" },
                    resolve: @escaping (String) -> String? = { _ in nil }, now: Date = Date()) {
            self.values = values; self.clipboard = clipboard; self.resolve = resolve; self.now = now
        }
    }

    public static func render(_ s: String, _ ctx: Context, depth: Int = 0) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for t in tokenize(s) {
            switch t {
            case .text(let x): out += x
            case .variable(let v):
                let value = ctx.values[v.name] ?? ""
                out += value.isEmpty ? v.defaultValue : value
            case .builtin(let b): out += builtin(b, ctx)
            case .include(let name):
                if depth < 8, let body = ctx.resolve(name) { out += render(body, ctx, depth: depth + 1) }
                else { out += "{{> \(name)}}" }
            }
        }
        return out
    }

    static func builtin(_ name: String, _ ctx: Context) -> String {
        let f = DateFormatter()
        switch name {
        case "date": f.dateFormat = "yyyy-MM-dd"; return f.string(from: ctx.now)
        case "time": f.dateFormat = "HH:mm"; return f.string(from: ctx.now)
        case "datetime": f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: ctx.now)
        case "weekday": f.dateFormat = "EEEE"; return f.string(from: ctx.now)
        case "uuid": return UUID().uuidString.lowercased()
        case "clipboard": return ctx.clipboard()
        default: return ""
        }
    }

    /// Rough token estimate (cl100k/Claude-ish): ~4 chars per token for prose, denser for code.
    public static func estimateTokens(_ s: String) -> Int { estimateTokens(length: s.utf8.count) }

    public static func estimateTokens(length n: Int) -> Int {
        guard n > 0 else { return 0 }
        return max(1, Int((Double(n) / 3.8).rounded()))
    }
}
