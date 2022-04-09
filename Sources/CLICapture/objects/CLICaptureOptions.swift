//
//  CLICaptureOptions.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

/// Option Set defining how to handle capture Exection Output
public struct CLICaptureOptions: OptionSet {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue & CLICaptureOptions.mask  }
    
    /// Do not passthrough output and do not capture output
    public static let none: CLICaptureOptions = .init(rawValue: 0)
    
    /// Capture the cli execution STD output and return in results as string
    public static let out: CLICaptureOptions = .init(rawValue: CLIPassthroughOptions.highestSingleValue << 1)
    /// Capture the cli execution STD error and return in results as string
    public static let err: CLICaptureOptions = .init(rawValue: CLIPassthroughOptions.highestSingleValue << 2)
    /// Capture the cli execution STD out and error and return in results as strings
    public static let all: CLICaptureOptions = .out + .err
    
    /// Indicates the lowest bit within RawValue  that is used
    internal static let leastSignificantShiftBit: Int = CLIPassthroughOptions.mostSignificantShiftBit + 1
    /// Indicates the hightest bit within RawValue  that is used
    internal static let mostSignificantShiftBit: Int = CLICaptureOptions.leastSignificantShiftBit + 1
    
    /// The max individual value from the set
    internal private(set) static var highestSingleValue: RawValue = {
        return (1 << CLICaptureOptions.mostSignificantShiftBit)
    }()
    
    /// The min individual value from the set
    internal private(set) static var smallestSingleValue: RawValue = {
        return (1 << CLICaptureOptions.leastSignificantShiftBit)
    }()
    
    /// The mask to use to capture only usable values from a raw value
    internal private(set) static var mask: RawValue = {
        var rtn: RawValue = 0
        for i in CLICaptureOptions.leastSignificantShiftBit...CLICaptureOptions.mostSignificantShiftBit {
            rtn = rtn | (1 << i)
        }
        return rtn
    }()
    
    
    public static func +(lhs: CLICaptureOptions,
                         rhs: CLICaptureOptions) -> CLICaptureOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
    public static func +(lhs: CLICaptureOptions,
                         rhs: CLIPassthroughOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
    public static func +(lhs: CLICaptureOptions,
                         rhs: CLIOutputOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
}

extension CLICaptureOptions: CustomStringConvertible {
    public var description: String {
        
        var rtn: String = "["
        
        if self.contains(.all) { rtn += "all" }
        else if self.contains(.out) { rtn += "out" }
        else if self.contains(.err) { rtn += "err" }
        
        if rtn == "[" { rtn += "none" }
        rtn += "]"
        return rtn
    }
}
