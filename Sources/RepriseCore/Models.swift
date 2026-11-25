import Foundation

public typealias ID = Int64

/// A top-level area of your life/work: "Client work", "Open source", "Research".
public struct Space: Identifiable, Hashable, Sendable {
    public var id: ID
    public var name: String
    public var color: String   // hex
    public var icon: String    // SF Symbol name
    public var sort: Double
}

/// A named project inside a space. Every prompt lives in exactly one project.
public struct Project: Identifiable, Hashable, Sendable {
    public var id: ID
    public var spaceID: ID
    public var name: String
    public var color: String
    public var sort: Double
}

/// Lightweight list row — never carries the full body, so lists of 100k items stay instant.
public struct PromptSummary: Identifiable, Hashable, Sendable {
    public var id: ID
    public var projectID: ID
    public var title: String
    public var snippet: String
    public var color: String
    public var pinned: Bool
    public var isTemplate: Bool
    public var useCount: Int
    public var updatedAt: Date
    public var length: Int
}

public struct Prompt: Identifiable, Hashable, Sendable {
    public var id: ID
    public var projectID: ID
    public var title: String
    public var body: String
    public var color: String
    public var tags: String
    public var pinned: Bool
    public var useCount: Int
    public var lastUsedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var slug: String
    public var exportCommand: Bool
    public var trashed: Bool

    public var isTemplate: Bool { Template.hasPlaceholders(body) }
}

public struct Attachment: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case image, file, link }
    public var id: ID
    public var promptID: ID
    public var kind: Kind
    public var name: String
    /// For images/files: absolute path inside the library's attachments folder. For links: the URL.
    public var value: String
    public var createdAt: Date
}

public struct PromptVersion: Identifiable, Hashable, Sendable {
    public var id: ID
    public var promptID: ID
    public var title: String
    public var body: String
    public var createdAt: Date
}

public enum PromptScope: Hashable, Sendable {
    case all, pinned, templates, recent, trash
    case space(ID)
    case project(ID)
}

public enum PromptSort: String, CaseIterable, Sendable, Identifiable {
    case edited = "Last edited"
    case used = "Most used"
    case created = "Newest"
    case name = "Name"
    public var id: String { rawValue }
}

public extension String {
    /// "Review this PR for race conditions" -> "review-this-pr-for-race-conditions"
    var slugified: String {
        let lowered = folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        var out = ""
        var lastDash = false
        for ch in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(ch) && ch.isASCII {
                out.unicodeScalars.append(ch); lastDash = false
            } else if !lastDash && !out.isEmpty {
                out.append("-"); lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return String(out.prefix(48))
    }
}
