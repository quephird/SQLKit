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

    func testBuildingOneStatementFromAnother() {
        let anotherStatement = SQLStatement("where foo = 1 and bar = 2")
        let oneStatement = SQLStatement("select * from baz \(anotherStatement)")
        let segments: [SQLStatement.Segment] = [
            .raw("select * from baz "),
            .raw("where foo = 1 and bar = 2"),
            .raw(""),
        ]
        XCTAssertEqual(oneStatement.segments, segments)
    }

    func testBuildingOneStatementFromAnotherWithInterpolations() {
        let fooId = 1
        let barId = 2
        let anotherStatement = SQLStatement("where foo = \(fooId) and bar = \(barId)")
        let oneStatement = SQLStatement("select * from baz \(anotherStatement)")
        let segments: [SQLStatement.Segment] = [
            .raw("select * from baz "),
            .raw("where foo = "),
            .parameter(1),
            .raw(" and bar = "),
            .parameter(2),
            .raw(""),
            .raw(""),
        ]
        XCTAssertEqual(oneStatement.segments, segments)
    }

    func testBuildingStatementByInterpolatingArbitraryType() {
        let id = UUID(uuidString: "C19B311E-1276-4FBC-9E81-D3E6510C2818")!
        let statement = SQLStatement("select foo from bar where id = \(id)")
        let segments: [SQLStatement.Segment] = [
            .raw("select foo from bar where id = "),
            .parameter(id.uuidString),
            .raw(""),
        ]
        XCTAssertEqual(statement.segments, segments)
    }

    func testBuildingStatementByInterpolatingAnArrayOfInts() {
        let id = [1, 2]
        let statement = SQLStatement("select foo from bar where id in (\(array: id))")
        let segments: [SQLStatement.Segment] = [
            .raw("select foo from bar where id in ("),
            .parameter(1),
            .raw(", "),
            .parameter(2),
            .raw(")"),
        ]
        XCTAssertEqual(statement.segments, segments)
    }

    func testBuildingStatementByInterpolatingAnArrayOfStrings() {
        let id = ["P1", "P2"]
        let statement = SQLStatement("select foo from bar where id in (\(array: id))")
        let segments: [SQLStatement.Segment] = [
            .raw("select foo from bar where id in ("),
            .parameter("P1"),
            .raw(", "),
            .parameter("P2"),
            .raw(")"),
        ]
        XCTAssertEqual(statement.segments, segments)
    }
}
