//
//  XCTAsserts.swift
//  
//
//  Created by Tyler Anger on 2022-04-07.
//

import XCTest

//MARK: - Equals
#if swift(>=5.3)
/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAssertsEqual<T>(_ expression1: @autoclosure () throws -> T,
                        _ expression2: @autoclosure () throws -> T,
                        _ message: @autoclosure () -> String = "",
                        file: StaticString = #filePath,
                        line: UInt = #line) rethrows -> Bool where T : Equatable {
    let e1 = try expression1()
    let e2 = try expression2()
    
    XCTAssertEqual(e1, e2, message(), file: file, line: line)
    
    return e1 == e2
}

/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAssertsNotEqual<T>(_ expression1: @autoclosure () throws -> T,
                        _ expression2: @autoclosure () throws -> T,
                        _ message: @autoclosure () -> String = "",
                        file: StaticString = #filePath,
                        line: UInt = #line) rethrows -> Bool where T : Equatable {
    let e1 = try expression1()
    let e2 = try expression2()
    
    XCTAssertNotEqual(e1, e2, message(), file: file, line: line)
    
    return e1 != e2
}
#else
/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAssertsEqual<T>(_ expression1: @autoclosure () throws -> T,
                        _ expression2: @autoclosure () throws -> T,
                        _ message: @autoclosure () -> String = "",
                        file: StaticString = #file,
                        line: UInt = #line) rethrows -> Bool where T : Equatable {
    let e1 = try expression1()
    let e2 = try expression2()
    
    XCTAssertEqual(e1, e2, message(), file: file, line: line)
    
    return e1 == e2
}

/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAssertsNotEqual<T>(_ expression1: @autoclosure () throws -> T,
                        _ expression2: @autoclosure () throws -> T,
                        _ message: @autoclosure () -> String = "",
                        file: StaticString = #file,
                        line: UInt = #line) rethrows -> Bool where T : Equatable {
    let e1 = try expression1()
    let e2 = try expression2()
    
    XCTAssertNotEqual(e1, e2, message(), file: file, line: line)
    
    return e1 != e2
}
#endif
