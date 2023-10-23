//
//  File.swift
//  
//
//  Created by Danielle Kefford on 10/22/23.
//

import XCTest
import SQLKit

enum MockSQLClient: SQLClient {
    public struct DatabaseState {}
    public struct ConnectionState {}
    public struct QueryState {}
    public struct RowState {
        public var row = [
            "P1" as SQLValue?,
            "Nut" as SQLValue?,
            "Red" as SQLValue?,
            12.0 as SQLValue?,
            "London" as SQLValue?,
            nil as SQLValue?,
        ]
    }
    typealias RowStateSequence = [RowState]

    static func makeDatabaseState(url: URL) -> DatabaseState {
        DatabaseState()
    }
    
    static func makeConnectionState(with databaseState: DatabaseState) throws -> ConnectionState {
        ConnectionState()
    }
    
    static func execute(_ statement: SQLKit.SQLStatement, with connectionState: ConnectionState) throws {
        fatalError()
    }
    
    static func execute<Value>(_ statement: SQLKit.SQLStatement, returningIDs idColumnName: String, as idType: Value.Type, with connectionState: ConnectionState) throws -> AnySequence<Value> where Value : SQLKit.SQLValue {
        fatalError()
    }
    
    static func makeQueryState(_ statement: SQLKit.SQLStatement, with connectionState: ConnectionState) throws -> QueryState {
        fatalError()
    }
    
    static func columnIndex<Value>(forName name: String, as valueType: Value.Type, with queryState: QueryState) throws -> Int? where Value : SQLKit.SQLValue {
        fatalError()
    }
    
    static func columnName<Value>(at index: Int, as valueType: Value.Type, with queryState: QueryState) throws -> String? where Value : SQLKit.SQLValue {
        fatalError()
    }
    
    static func count(with queryState: QueryState) -> Int {
        fatalError()
    }
    
    static func makeRowStateSequence(with queryState: QueryState) -> [RowState] {
        fatalError()
    }
    
    static func value<Value>(for key: SQLKit.SQLColumnKey<Value>, with rowState: RowState) throws -> Value? where Value : SQLKit.SQLValue {
        guard key.index >= 0, key.index < rowState.row.count else {
            throw SQLColumnError.columnMissing
        }

        guard let value = rowState.row[key.index] as? Value? else {
            throw SQLValueError.typeUnsupportedByClient(valueType: Value.self, client: self)
        }

        return value
    }

    static func supports(_ url: URL) -> Bool {
        false
    }
}

class SQLRowTests: XCTestCase {
    func testRowLookupSucceeds() throws {
        let row = SQLRow<MockSQLClient>(statement: SQLStatement(), state: MockSQLClient.RowState())
        let testKey = SQLColumnKey<String>(index: 0, name: "id")
        let actualValue = try row.value(for: testKey)

        XCTAssertEqual(actualValue, "P1")
    }

    func testRowLookupWithKeyWithIndexOutOfRangeFails() throws {
        let row = SQLRow<MockSQLClient>(statement: "select id from parts", state: MockSQLClient.RowState())
        let testKey = SQLColumnKey<Int>(index: 42, name: "nonexistent")

        XCTAssertThrowsError(try row.value(for: testKey)) { error in
            switch error {
            case SQLError.valueInvalid(let underlyingError, let key, let statement):
                if case SQLColumnError.columnMissing = underlyingError {
                    XCTAssertEqual(key.index, 42)
                    XCTAssertEqual(key.name, "nonexistent")
                    XCTAssertEqual(statement, "select id from parts")
                } else {
                    XCTFail("Unexpected underlying error thrown")
                }
            default:
                XCTFail("Unexpected top-level error thrown")
            }
        }
    }

    func testRowLookupForKeyWithWrongType() throws {
        let row = SQLRow<MockSQLClient>(statement: "select id from parts", state: MockSQLClient.RowState())
        let testKey = SQLColumnKey<Int>(index: 0, name: "id")

        XCTAssertThrowsError(try row.value(for: testKey)) { error in
            switch error {
            case SQLError.valueInvalid(let underlyingError, let key, let statement):
                if case SQLValueError.typeUnsupportedByClient = underlyingError {
                    XCTAssertEqual(key.index, 0)
                    XCTAssertEqual(key.name, "id")
                    XCTAssertEqual(statement, "select id from parts")
                } else {
                    XCTFail("Unexpected underlying error thrown")
                }
            default:
                XCTFail("Unexpected top-level error thrown")
            }
        }
    }

    // TODO: Test retrieval of null value with SQLColumnKey
    // TODO: Test usage of SQLNullableColumnKey
}
