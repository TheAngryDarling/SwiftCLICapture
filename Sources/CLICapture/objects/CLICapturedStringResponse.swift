//
//  CLICapturedStringResponse.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

/// Structure containing the response from the execution of the cli
public struct CLICapturedStringResponse: CLICapturedResponse {
    /// The return code from the execution of the cli process
    public let exitStatusCode: Int32
    /// The STD Out as a string if the option set indicated to capture it
    public let out: String?
    /// The STD Err as a string if the option set indicated to capture it
    public let err: String?
    /// The combination of STD Out and STD Err as a string if the option set indicated to capture it
    public let output: String?
    
    public init<DATA>(exitStatusCode: Int32,
                      captureOptions: CLICaptureOptions,
                      capturedEvents: [CLICapturedOutputEvent<DATA>]) {
        self.exitStatusCode = exitStatusCode
        
        var sOut: String? = nil
        var sErr: String? = nil
        var sOutput: String? = nil
        
        for outputEvent in capturedEvents {
            if let str = String(bytes: outputEvent.data, encoding: .utf8) {
                if outputEvent.isOut {
                    sOut = (sOut ?? "") + str
                } else if outputEvent.isErr {
                    sErr = (sErr ?? "") + str
                }
                if captureOptions.contains(.all) {
                    sOutput = (sOutput ?? "") + str
                }
            }
        }
        if captureOptions.contains(.out) &&
           sOut == nil {
            sOut = ""
        }
        if captureOptions.contains(.err) &&
           sErr == nil {
            sErr = ""
        }
        if captureOptions.contains(.all) &&
           sOutput == nil {
            sOutput = ""
        }
        
        self.out = sOut
        self.err = sErr
        self.output = sOutput
    }
}
