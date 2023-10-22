//
//  SQLStatementTests.swift
//
//
//  Created by Danielle Kefford on 10/21/23.
//

import XCTest
import SQLKit

class SQLStatementTests: XCTestCase {
    func testStatementWithOneSegment() {
        let statement = SQLStatement("select foo from bar")
        let segment: SQLStatement.Segment = .raw("select foo from bar")
        XCTAssertEqual(statement.segments, [segment])
    }

    func testStatementWithMultipleSegments() {
        let id = 42
        let statement = SQLStatement("select foo from bar where id = \(id)")
        let segments: [SQLStatement.Segment] = [
            .raw("select foo from bar where id = "),
            .parameter(42),
            .raw(""),
        ]
        XCTAssertEqual(statement.segments, segments)
    }
}
