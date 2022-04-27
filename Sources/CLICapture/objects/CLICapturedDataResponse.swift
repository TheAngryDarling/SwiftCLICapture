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
    /// The output data events captured
    public let capturedEvents: [CLICapturedOutputEvent<DATA>]
    /// The capture options used to collect  the output data
    public let captureOptions: CLICaptureOptions
    
    public init<OtherData>(exitStatusCode: Int32,
                           captureOptions: CLICaptureOptions,
                           capturedEvents: [CLICapturedOutputEvent<OtherData>]) {
        self.exitStatusCode = exitStatusCode
        self.captureOptions = captureOptions
        // Cast capturedEvents as our data type or map to our data type
        self.capturedEvents = (capturedEvents as? [CLICapturedOutputEvent<DATA>]) ?? capturedEvents.map { return CLICapturedOutputEvent<DATA>($0) }
    }
}

extension CLICapturedDataResponse {
    private func getData(for eventType: CLICaptureOptions) -> DATA? {
        // Make sure we were set to capture events of 'eventType'
        guard self.captureOptions.contains(eventType) else {
            return nil
        }
        // Create our return variable
        var rtn = DATA([])
        // Loop through all events
        for event in self.capturedEvents {
            // Make sure the event is one we want
            guard event.matchesCapture(eventType) else {
                continue
            }
            rtn.append(event.data)
        }
        return rtn
    }
    /// Get all the STD Out Data
    ///
    /// Note: This property generates its value
    /// on every call from capturedEvents.
    /// It is better to call once and reference variable
    /// than to repeatedly call this property
    public var out: DATA? {
        return self.getData(for: .out)
    }
    /// Get all the STD Err Data
    ///
    /// Note: This property generates its value
    /// on every call from capturedEvents.
    /// It is better to call once and reference variable
    /// than to repeatedly call this property
    public var err: DATA? {
        return self.getData(for: .err)
    }
    
    /// Get all the Output Data
    ///
    /// Note: This property generates its value
    /// on every call from capturedEvents.
    /// It is better to call once and reference variable
    /// than to repeatedly call this property
    public var output: DATA? {
        return self.getData(for: .all)
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
