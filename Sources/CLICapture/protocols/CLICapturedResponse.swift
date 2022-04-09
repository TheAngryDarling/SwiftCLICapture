//
//  CLICapturedResponse.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

public protocol CLICapturedResponse {
    /// The return code from the execution of the cli process
    var exitStatusCode: Int32 { get }
    
    /// Create a new Captured Response
    /// - Parameters:
    ///   - exitStatusCode: The termination status code
    ///   - captureOptions: The options detailing which type of events were captured
    ///   - capturedEvents: The captured output events
    init<DATA>(exitStatusCode: Int32,
               captureOptions: CLICaptureOptions,
               capturedEvents: [CLICapturedOutputEvent<DATA>]) throws
    
}

public extension CLICapturedResponse {
    
    /// Create a new Captured Response
    /// - Parameters:
    ///   - exitStatusCode: The termination status code
    ///   - outputOptions: The options detailing which type of events were captured and / or passthrough
    ///   - capturedEvents: The captured output events
    init<DATA>(exitStatusCode: Int32,
               outputOptions: CLIOutputOptions,
               capturedEvents: [CLICapturedOutputEvent<DATA>]) throws {
        try self.init(exitStatusCode: exitStatusCode,
                      captureOptions: outputOptions.capture,
                      capturedEvents: capturedEvents)
    }
    
    /// Create a new Captured Response
    /// - Parameters:
    ///   - other: A CLI Captured Data Response
    init<OtherData>(_ other: CLICapturedDataResponse<OtherData>) throws {
       try self.init(exitStatusCode: other.exitStatusCode,
                     captureOptions: other.captureOptions,
                     capturedEvents: other.capturedEvents)
   }
}
