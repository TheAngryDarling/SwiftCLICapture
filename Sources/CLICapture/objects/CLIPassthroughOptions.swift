//
//  CLIPassthroughOptions.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

/// Option Set defining how to handle passthrough Exection Output to STD Streams
public struct CLIPassthroughOptions: OptionSet {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue & CLIPassthroughOptions.mask }
    
    /// Do not passthrough output and do not capture output
    public static let none: CLIPassthroughOptions = .init(rawValue: 0)
    /// Pass the cli exection STD output to the console ouptut
    public static let out: CLIPassthroughOptions = .init(rawValue: 1 << 0)
    /// Pass the cli exection STD error to the console error
    public static let err: CLIPassthroughOptions = .init(rawValue: 1 << 1)
    /// Pass through all STD outputs (out and err) from the cli process to our STD out and STD err
    public static let all: CLIPassthroughOptions = .out + .err
    
    /// Indicates the lowest bit within RawValue  that is used
    internal static let leastSignificantShiftBit: Int = 0
    /// Indicates the hightest bit within RawValue  that is used
    internal static let mostSignificantShiftBit: Int = 1
    
    /// The max individual value from the set
    internal private(set) static var highestSingleValue: RawValue = {
        return (1 << CLIPassthroughOptions.mostSignificantShiftBit)
    }()
    
    /// The min individual value from the set
    internal private(set) static var smallestSingleValue: RawValue = {
        return (1 << CLIPassthroughOptions.leastSignificantShiftBit)
    }()
    
    /// The mask to use to capture only usable values from a raw value
    internal private(set) static var mask: RawValue = {
        var rtn: RawValue = 0
        for i in CLIPassthroughOptions.leastSignificantShiftBit...CLIPassthroughOptions.mostSignificantShiftBit {
            rtn = rtn | (1 << i)
        }
        return rtn
    }()
    
    
    
    public static func +(lhs: CLIPassthroughOptions,
                         rhs: CLIPassthroughOptions) -> CLIPassthroughOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
    public static func +(lhs: CLIPassthroughOptions,
                         rhs: CLICaptureOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
    public static func +(lhs: CLIPassthroughOptions,
                         rhs: CLIOutputOptions) -> CLIOutputOptions {
        return .init(rawValue: (lhs.rawValue | rhs.rawValue))
    }
    
}

extension CLIPassthroughOptions: CustomStringConvertible {
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
