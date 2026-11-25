import Foundation
import SQLite3

/// A deliberately tiny, dependency-free SQLite wrapper.
/// Prepared statements are cached, so hot paths (list, search, save) never re-parse SQL.
public final class SQLite: @unchecked Sendable {
    public enum Value {
        case int(Int64)
        case double(Double)
        case text(String)
        case blob(Data)
        case null
    }

    public struct Failure: Error, CustomStringConvertible {
        public let message: String
        public var description: String { message }
    }

    public final class Row {
        fileprivate let stmt: OpaquePointer
        fileprivate init(_ stmt: OpaquePointer) { self.stmt = stmt }

        public func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
        public func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
        public func bool(_ i: Int32) -> Bool { sqlite3_column_int64(stmt, i) != 0 }
        public func isNull(_ i: Int32) -> Bool { sqlite3_column_type(stmt, i) == SQLITE_NULL }
        public func text(_ i: Int32) -> String {
            guard let c = sqlite3_column_text(stmt, i) else { return "" }
            return String(cString: c)
        }
        public func optionalDouble(_ i: Int32) -> Double? { isNull(i) ? nil : double(i) }
        public func optionalInt(_ i: Int32) -> Int64? { isNull(i) ? nil : int(i) }
    }

    private let db: OpaquePointer
    private var cache: [String: OpaquePointer] = [:]
    private let lock = NSRecursiveLock()
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw Failure(message: "Cannot open database at \(path)")
        }
        db = handle
        sqlite3_busy_timeout(db, 3000)
        try exec("""
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA foreign_keys = ON;
        PRAGMA temp_store = MEMORY;
        PRAGMA mmap_size = 268435456;
        PRAGMA cache_size = -32000;
        """)
    }

    deinit {
        for (_, s) in cache { sqlite3_finalize(s) }
        sqlite3_close_v2(db)
    }

    private var errorMessage: String { String(cString: sqlite3_errmsg(db)) }

    public func exec(_ sql: String) throws {
        lock.lock(); defer { lock.unlock() }
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? errorMessage
            sqlite3_free(err)
            throw Failure(message: msg)
        }
    }

    private func statement(_ sql: String) throws -> OpaquePointer {
        if let s = cache[sql] {
            sqlite3_reset(s)
            sqlite3_clear_bindings(s)
            return s
        }
        var s: OpaquePointer?
        guard sqlite3_prepare_v3(db, sql, -1, UInt32(SQLITE_PREPARE_PERSISTENT), &s, nil) == SQLITE_OK, let s else {
            throw Failure(message: "\(errorMessage) — in: \(sql)")
        }
        cache[sql] = s
        return s
    }

    private func bind(_ stmt: OpaquePointer, _ args: [Value]) {
        for (i, v) in args.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case .int(let n): sqlite3_bind_int64(stmt, idx, n)
            case .double(let d): sqlite3_bind_double(stmt, idx, d)
            case .text(let t): sqlite3_bind_text(stmt, idx, t, -1, SQLite.transient)
            case .blob(let d):
                _ = d.withUnsafeBytes { sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32(d.count), SQLite.transient) }
            case .null: sqlite3_bind_null(stmt, idx)
            }
        }
    }

    @discardableResult
    public func run(_ sql: String, _ args: [Value] = []) throws -> Int64 {
        lock.lock(); defer { lock.unlock() }
        let s = try statement(sql)
        bind(s, args)
        let rc = sqlite3_step(s)
        sqlite3_reset(s)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else { throw Failure(message: errorMessage) }
        return sqlite3_last_insert_rowid(db)
    }

    public func query<T>(_ sql: String, _ args: [Value] = [], _ map: (Row) throws -> T) throws -> [T] {
        lock.lock(); defer { lock.unlock() }
        let s = try statement(sql)
        bind(s, args)
        defer { sqlite3_reset(s) }
        var out: [T] = []
        let row = Row(s)
        while true {
            let rc = sqlite3_step(s)
            if rc == SQLITE_ROW { out.append(try map(row)) }
            else if rc == SQLITE_DONE { break }
            else { throw Failure(message: errorMessage) }
        }
        return out
    }

    public func scalarInt(_ sql: String, _ args: [Value] = []) throws -> Int64 {
        try query(sql, args) { $0.int(0) }.first ?? 0
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        try exec("BEGIN IMMEDIATE")
        do {
            let r = try body()
            try exec("COMMIT")
            return r
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }
}

public extension SQLite.Value {
    static func optional(_ s: String?) -> SQLite.Value { s.map { .text($0) } ?? .null }
    static func optional(_ d: Double?) -> SQLite.Value { d.map { .double($0) } ?? .null }
    static func optional(_ n: Int64?) -> SQLite.Value { n.map { .int($0) } ?? .null }
    static func bool(_ b: Bool) -> SQLite.Value { .int(b ? 1 : 0) }
}
