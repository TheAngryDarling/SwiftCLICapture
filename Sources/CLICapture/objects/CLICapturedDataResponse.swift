//
//  CLICapturedDataResponse.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

/// Object containing the Process terminationStatus and all output data captured
public struct CLICapturedDataResponse<DATA: CLICapturedData>: CLICapturedResponse {
    /// The return code from the execution of the cli process
    public let exitStatusCode: Int32
    /// The output data evetns captured
    public let capturedEvents: [CLICapturedOutputEvent<DATA>]
    /// The capture options used to collect  the output data
    public let captureOptions: CLICaptureOptions
    
    public init<OtherData>(exitStatusCode: Int32,
                           captureOptions: CLICaptureOptions,
                           capturedEvents: [CLICapturedOutputEvent<OtherData>]) {
        self.exitStatusCode = exitStatusCode
        self.captureOptions = captureOptions
        self.capturedEvents = (capturedEvents as? [CLICapturedOutputEvent<DATA>]) ?? capturedEvents.map { return CLICapturedOutputEvent<DATA>($0) }
    }
}



public extension CLICapturedDataResponse {
    /// Re-wraps the captured output data to new type
    func usingContainerType<T>(_ type: T.Type) -> CLICapturedDataResponse<T> {
        return .init(exitStatusCode: self.exitStatusCode,
                     captureOptions: captureOptions,
                     capturedEvents: self.capturedEvents)
    }
}
