//
//  CLIOutputOptions.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

/// Option Set defining how to handle CLI Exection Output
public struct CLIOutputOptions: OptionSet {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue & CLIOutputOptions.mask }
    
    public init(passthrough: CLIPassthroughOptions) { self.rawValue = passthrough.rawValue }
    public init(capture: CLICaptureOptions) { self.rawValue = capture.rawValue }
    /// Property containing specific options for capturing output
    public var capture: CLICaptureOptions { return .init(rawValue: self.rawValue) }
    /// Property containing specific options for passthrough options
    public var passthrough: CLIPassthroughOptions { return .init(rawValue: self.rawValue ) }
    
    /// Do not passthrough output and do not capture output
    public static let none: CLIOutputOptions = .init(rawValue: 0)
    /// Pass the cli exection STD output to the console ouptut
    public static let passthroughOut: CLIOutputOptions = .init(passthrough: .out)
    /// Pass the cli exection STD error to the console error
    public static let passthroughErr: CLIOutputOptions = .init(passthrough: .err)
    /// Pass through all STD outputs (out and err) from the cli process to our STD out and STD err
    public static let passthroughAll: CLIOutputOptions = .init(passthrough: .all)
    /// Capture the cli execution STD output and return in results as string
    public static let captureOut: CLIOutputOptions = .init(capture: .out)
    /// Capture the cli execution STD error and return in results as string
    public static let captureErr: CLIOutputOptions = .init(capture: .err)
    /// Capture the cli execution STD out and error and return in results as strings
    public static let captureAll: CLIOutputOptions = .init(capture: .all)
    
    public static let all: CLIOutputOptions = .passthroughAll + .captureAll
    
    /// Indicates the lowest bit within RawValue  that is used
    internal static let leastSignificantShiftBit: Int = CLIPassthroughOptions.leastSignificantShiftBit
    /// Indicates the hightest bit within RawValue  that is used
    internal static let mostSignificantShiftBit: Int = CLICaptureOptions.mostSignificantShiftBit
    
    /// The max individual value from the set
    internal private(set) static var highestSingleValue: RawValue = {
        return (1 << CLIOutputOptions.mostSignificantShiftBit)
    }()
    
    /// The min individual value from the set
    internal private(set) static var smallestSingleValue: RawValue = {
        return (1 << CLIOutputOptions.leastSignificantShiftBit)
    }()
    
    /// The mask to use to capture only usable values from a raw value
    internal static let mask: RawValue = CLIPassthroughOptions.mask | CLICaptureOptions.mask
    
    
    public static func +(lhs: CLIOutputOptions,
                         rhs: CLIOutputOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
    public static func +(lhs: CLIOutputOptions,
                         rhs: CLIPassthroughOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
    public static func +(lhs: CLIOutputOptions,
                         rhs: CLICaptureOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
}

extension CLIOutputOptions: CustomStringConvertible {
    public var description: String {
        var rtn: String = "["
        if self.contains(.all) {
            rtn += "all"
        } else if self.isEmpty {
            rtn += "none"
        } else {
            if !self.passthrough.isEmpty {
                var description = self.passthrough.description
                description.removeFirst()
                description.removeLast()
                rtn += "passthrough" + description.prefix(1).capitalized
                rtn += description.dropFirst()
            }
            
            if !self.capture.isEmpty {
                var description = self.capture.description
                description.removeFirst()
                description.removeLast()
                rtn += "capture" + description.prefix(1).capitalized
                rtn += description.dropFirst()
            }
        }
        rtn += "]"
        return rtn
    }
}
