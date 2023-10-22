//
//  SQLStatement.swift
//  LittlinkRouterPerfect
//
//  Created by Becca Royal-Gordon on 10/29/16.
//
//

/// Conforming types can be implicitly converted into `SQLStatement`s, and 
/// interpolating them will cause them to be concatenated with the surrounding 
/// statement, rather than passed as a parameter.
/// 
/// - Warning: No type should ever conform to both `SQLStatementConvertible` and 
///              `SQLValue`. In particular, `String` should never conform to 
///              `SQLStatementConvertible`; doing so would break `SQLStatement`'s 
///              interpolation safety.
/// 
/// - SeeAlso: `SQLStatement`
public protocol SQLStatementConvertible {
    /// Returns the SQL statement equivalent of the instance. Do not call this 
    /// directly; instead, use the `SQLStatement(_:)` initializer, or concatenate or 
    /// interpolate the type with a `SQLStatement`.
    /// 
    /// - Recommended: `SQLStatement(_: SQLStatementConvertible)`
    var sqlStatement: SQLStatement { get }
}

/// Represents a SQL statement or a fragment thereof.
/// 
/// `SQLStatement`s can be created using the `init(raw:)` and `init(parameter:)` 
/// initializers, but more frequently they are built using string literal syntax. 
/// `SQLStatement` supports string interpolation, and interpolating a type 
/// which conforms to `SQLValue` will cause it to be passed safely to the server, 
/// rather than inserted directly into the raw SQL. In other words, code like this is 
/// *not* vulnerable to SQL injection:
/// 
///     let id: Int = …
///     let name: String = …
///     
///     // Note: `SQLConnection.execute(_:)` takes a `SQLStatement`, not a 
///     // plain `String`.
///     try connection.execute("UPDATE users SET name = \(name) WHERE id = \(id)")
/// 
/// On the other hand, interpolating a `SQLStatementConvertible` type (including 
/// `SQLStatement` itself) *does* insert it directly, so if you actually intend to 
/// inject SQL in the middle of a query, you can simply interpolate a `SQLStatement` 
/// instead of a `String`:
/// 
///     let id = …
///     let fieldName = SQLStatement(raw: …)
///     
///     try connection.execute(UPDATE users SET name = \(fieldName) WHERE id = \(id)")
/// 
/// A `SQLStatement` consists of a series of `Segment`s, each of which is either 
/// raw SQL or a parameter which should be passed safely to the server. Because 
/// different database engines support different placeholder syntaxes—or, in some 
/// cases, none at all—each client must determine for itself how it will convert a 
/// `SQLStatement` into parameters and a flat query string; the 
/// `rawSQLByReplacingParameters(with:)` method can help with that.
public struct SQLStatement: Hashable {
    /// An individual piece of a `SQLStatement`. Each segment is either `raw`, 
    /// in which case it represents a fragment of pre-escaped SQL which should be 
    /// passed directly to the server, or `parameter`, in which case it represents a 
    /// piece of data which should be passed to the server either through a 
    /// placeholder or by escaping it.
    public enum Segment {
        case raw (String)
        case parameter (SQLValue?)
        
        func replacingParameter(with mapping: (SQLValue?) throws -> String) rethrows -> String {
            switch self {
            case .raw(let sqlFragment):
                return sqlFragment
            case .parameter(let value):
                return try mapping(value)
            }
        }
    }
    
    /// The segments comprising this `SQLStatement`.
    public var segments: [Segment]
    
    /// Creates an empty `SQLStatement`.
    public init() {
        segments = []
    }
    
    /// Creates a `SQLStatement` consisting of a single segment of raw SQL.
    public init(raw sql: String) {
        segments = [.raw(sql)]
    }
    
    /// Creates a `SQLStatement` consisting of a single parameter which must be 
    /// passed by placeholder or escaped.
    public init(parameter value: SQLValue?) {
        segments = [.parameter(value)]
    }
    
    /// Creates a `SQLStatement` from a `SQLStatementConvertible` instance.
    public init(_ convertible: SQLStatementConvertible) {
        self = convertible.sqlStatement
    }
    
    /// Creates a `SQLStatement` from another `SQLStatement`. This can be used to 
    /// force Swift to treat a context-free string literal as a `SQLStatement`:
    /// 
    ///     let sql = SQLStatement("SELECT * FROM users")
    public init(_ statement: SQLStatement) {
        self = statement
    }
    
    /// Appends the segments in the other `SQLStatement` or convertible instance to 
    /// this `SQLStatement`.
    public mutating func append(_ other: SQLStatementConvertible) {
        segments += SQLStatement(other).segments
    }
    
    /// Converts the `SQLStatement` into raw SQL in a `String`, using the 
    /// `mapping` function to convert parameters into raw SQL.
    /// 
    /// `rawSQLByReplacingParameters(with:)` is primarily a utility method for 
    /// `SQLCient`s to use when implementing support for `execute(_:)`, 
    /// `execute(_:returningID:as:)`, and `query(_:)`. The `mapping` function 
    /// should be used to either escape parameters:
    /// 
    ///     let rawSQL = sql.rawSQLByReplacingParameters(with: myEscapingFunction)
    ///
    /// Or to bind them to the query and return appropriate placeholder syntax:
    /// 
    ///     var parameters: [String?] = []
    ///     let rawSQL = sql.rawSQLByReplacingParameters { value in 
    ///         parameters.append(value.sqlLiteral)
    ///         return "$" + String(parameters.count)
    ///     }
    public func rawSQLByReplacingParameters(with mapping: (_ value: SQLValue?) throws -> String) rethrows -> String {
        return try segments.map {
            try $0.replacingParameter(with: mapping)
        }.joined()
    }
}

extension SQLStatement {
    /// Appends raw SQL in a string to the statement.
    public mutating func append(raw sql: String) {
        append(SQLStatement(raw: sql))
    }
    
    /// Appends a safely-passed parameter to the statement.
    public mutating func append(parameter value: SQLValue?) {
        append(SQLStatement(parameter: value))
    }
    
    /// Returns the concatenation of `self` and the statement created by `other`.
    public func appending(_ other: SQLStatementConvertible) -> SQLStatement {
        var copy = self
        copy.append(other)
        return copy
    }
    
    /// Returns the concatenation of `self` and the raw SQL in the string. 
    public func appending(raw sql: String) -> SQLStatement {
        var copy = self
        copy.append(raw: sql)
        return copy
    }
    
    // Returns the concatenation of `self` and the safely-passed parameter. 
    public func appending(parameter value: SQLValue?) -> SQLStatement {
        var copy = self
        copy.append(parameter: value)
        return copy
    }
}

/// Appends another `SQLStatement` or convertible instance to a `SQLStatement`.  
public func += (lhs: inout SQLStatement, rhs: SQLStatementConvertible) {
    lhs.append(rhs)
}

/// Returns the concatenation of two `SQLStatement`s or convertible instances.
public func + (lhs: SQLStatementConvertible, rhs: SQLStatementConvertible) -> SQLStatement {
    var statement = SQLStatement(lhs)
    statement += rhs
    return statement
}

extension SQLStatement: SQLStatementConvertible {
    /// Returns `self`.
    public var sqlStatement: SQLStatement {
        return self
    }
}

extension SQLStatement: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(raw: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(raw: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(raw: value)
    }
}

extension SQLStatement: ExpressibleByStringInterpolation {
    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        var sqlStatement: SQLStatement

        public init(literalCapacity: Int, interpolationCount: Int) {
            sqlStatement = SQLStatement()
            sqlStatement.segments.reserveCapacity(2*interpolationCount + 1)
        }

        public mutating func appendLiteral(_ literal: String) {
            sqlStatement.append(raw: literal)
        }

        public mutating func appendInterpolation(_ interpolation: SQLValue?) {
            sqlStatement.append(parameter: interpolation)
        }

        public mutating func appendInterpolation(array interpolation: [SQLValue?]) {
            guard let firstElement = interpolation.first else {
                return
            }

            sqlStatement.append(parameter: firstElement)

            for element in interpolation.dropFirst() {
                sqlStatement.append(raw: ", ")
                sqlStatement.append(parameter: element)
            }
        }

        public mutating func appendInterpolation(_ interpolation: SQLStatementConvertible) {
            sqlStatement.append(interpolation)
        }

        @_disfavoredOverload
        public mutating func appendInterpolation<T>(_ interpolation: T) {
            sqlStatement.append(parameter: String(describing: interpolation))
        }
    }

    public init(stringInterpolation: StringInterpolation) {
        self = stringInterpolation.sqlStatement
    }
}

extension SQLStatement.Segment: Equatable {
    public static func == (lhs: SQLStatement.Segment, rhs: SQLStatement.Segment) -> Bool {
        switch (lhs, rhs) {
        case (.raw(let lSQL), .raw(let rSQL)):
            return lSQL == rSQL

        case (.parameter(let lValue), .parameter(let rValue)):
            return (lValue as? AnyHashable) == (rValue as? AnyHashable)

        case (.raw, .parameter), (.parameter, .raw):
            return false
        }
    }
}

extension SQLStatement.Segment: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .raw(let sql):
            hasher.combine(sql)
            hasher.combine("raw")
        case .parameter(let value):
            hasher.combine(value as? AnyHashable)
            hasher.combine("parameter")
        }
    }
}

extension SQLStatement: CustomDebugStringConvertible {
    public var debugDescription: String {
        var lines: [String] = []
        
        let sql = rawSQLByReplacingParameters { value in
            let n = lines.count
            lines.append("    \(n): \(String(reflecting: value))")
            return "\\(\(n))"
        }
        lines.insert("SQLStatement: \(String(reflecting: sql))", at: 0)
        
        return lines.joined(separator: "\n")
    }
}

extension Collection where Iterator.Element: SQLStatementConvertible, SubSequence.Iterator.Element: SQLStatementConvertible {
    /// Joins a collection of `SQLStatementConvertible` instances together with 
    /// `separator` between each one.
    /// 
    /// - Note: If `self` is empty, returns an empty `SQLStatement`.
    func joined(separator: SQLStatementConvertible) -> SQLStatement {
        let sep = SQLStatement(separator)
        guard let first = self.first else {
            return SQLStatement()
        }
        let rest = dropFirst()
        return rest.reduce(SQLStatement(first)) { left, right in left + sep + right }
    }
}
