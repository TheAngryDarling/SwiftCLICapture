//
//  CLICapturedOutputEvent.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation

/// An object that stores a captured output event
public enum CLICapturedOutputEvent<DATA: CLICapturedData> {
    
    case out(data: DATA, error: Int32, process: Process)
    case err(data: DATA, error: Int32, process: Process)
    
    
    /// Reference to the STD File Handle for the event type
    public var stdFileNo: Int32 {
        switch self {
            case .out(data: _, error: _, process: _):
                return STDOUT_FILENO
            case .err(data: _, error: _, process: _):
                return STDERR_FILENO
        }
    }
    /// Indicator if this event is an STD Out event
    public var isOut: Bool {
        guard case .out(data: _, error: _, process: _) = self else { return false }
        return true
    }
    /// Indicator if this event is an STD Err event
    public var isErr: Bool {
        guard case .err(data: _, error: _, process: _) = self else { return false }
        return true
    }
    
    /// The data of the event
    public var data: DATA {
        switch self {
            case .out(data: let rtn, error: _, process: _):
                    return rtn
            case .err(data: let rtn, error: _, process: _):
                    return rtn
        }
    }
    /// The process the event occured on
    public var process: Process {
        switch self {
            case .out(data: _, error: _, process: let rtn):
                    return rtn
            case .err(data: _, error: _, process: let rtn):
                    return rtn
        }
    }
    
    public init<OtherData>(_ other: CLICapturedOutputEvent<OtherData>) /*
        where OtherData: CapturedData, OtherData.Element == DATA.Element*/ {
            
        func convert(_ other: OtherData) -> DATA {
            return (other as? DATA) ?? DATA(other)
        }
    
        switch other {
            case .out(data: let dta,
                      error: let err,
                      process: let p):
                self = .out(data: convert(dta),
                            error: err,
                            process: p)
            case .err(data: let dta,
                      error: let err,
                      process: let p):
                self = .err(data: convert(dta),
                            error: err,
                            process: p)
        }
    }
    /// Method to see if this event can be captured with the given capture options
    public func matchesCapture(_ capture: CLICaptureOptions) -> Bool {
        switch self {
            case .out(data: _, error: _, process: _):
                return capture.contains(.out)
            case .err(data: _, error: _, process: _):
                return capture.contains(.err)
        }
    }
}



extension CLICapturedOutputEvent: Sequence {
    
    public typealias Element = DATA.Element
    public typealias Index = DATA.Index
}

extension CLICapturedOutputEvent: Collection {
    
    public typealias Indices = DATA.Indices
    public typealias SubSequence = DATA.SubSequence
    
    public var count: Int {
        #if swift(>=4.1)
        return self.data.count
        #else
        return self.data.count as! Int
        #endif
    }
    
    public var indices: Indices {
        return self.data.indices
    }
    
    public var startIndex: Index {
        return self.data.startIndex
    }
    
    public var endIndex: Index {
        return self.data.endIndex
    }
    
    public subscript(position: Index) -> Element {
        return self.data[position]
    }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        return self.data[bounds]
    }
    
    public func index(after i: Index) -> Index {
        return self.data.index(after: i)
    }
}
