import Foundation

nonisolated struct StatementDate: Comparable, Equatable, Sendable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    enum Error: Swift.Error, Equatable {
        case invalidComponents(year: Int, month: Int, day: Int)
        case malformedCanonical(String)
        case malformedAxisDate(String)
    }

    init(year: Int, month: Int, day: Int) throws {
        let leapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let monthLengths = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard year >= 1, (1...12).contains(month), (1...monthLengths[month - 1]).contains(day) else {
            throw Error.invalidComponents(year: year, month: month, day: day)
        }
        self.year = year
        self.month = month
        self.day = day
    }

    init(canonical: String) throws {
        let parts = canonical.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            throw Error.malformedCanonical(canonical)
        }
        try self.init(year: year, month: month, day: day)
        guard self.canonical == canonical else { throw Error.malformedCanonical(canonical) }
    }

    static func axisNRE(_ source: String) throws -> StatementDate {
        let parts = source.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw Error.malformedAxisDate(source)
        }
        do { return try StatementDate(year: year, month: month, day: day) }
        catch { throw Error.malformedAxisDate(source) }
    }

    var canonical: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var presentation: String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(String(format: "%02d", day)) \(names[month - 1]) \(String(format: "%02d", year % 100))"
    }

    static func < (lhs: StatementDate, rhs: StatementDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

nonisolated struct SelectedStatementMonth: Equatable, Sendable, Hashable, Comparable {
    let year: Int
    let month: Int

    enum Error: Swift.Error, Equatable {
        case invalidComponents(year: Int, month: Int)
        case malformedCanonical(String)
    }

    init(year: Int, month: Int) throws {
        guard year >= 1900, year <= 9999, (1...12).contains(month) else {
            throw Error.invalidComponents(year: year, month: month)
        }
        self.year = year
        self.month = month
    }

    init(canonical: String) throws {
        let pieces = canonical.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 2, pieces[0].count == 4, pieces[1].count == 2,
              let year = Int(pieces[0]), let month = Int(pieces[1]) else {
            throw Error.malformedCanonical(canonical)
        }
        try self.init(year: year, month: month)
        guard self.canonical == canonical else { throw Error.malformedCanonical(canonical) }
    }

    var canonical: String { String(format: "%04d-%02d", year, month) }

    static func < (lhs: SelectedStatementMonth, rhs: SelectedStatementMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

extension StatementDate: Codable {
    nonisolated init(from decoder: Decoder) throws {
        try self.init(canonical: decoder.singleValueContainer().decode(String.self))
    }
    nonisolated func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer(); try value.encode(canonical)
    }
}

extension SelectedStatementMonth: Codable {
    nonisolated init(from decoder: Decoder) throws {
        try self.init(canonical: decoder.singleValueContainer().decode(String.self))
    }
    nonisolated func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer(); try value.encode(canonical)
    }
}
