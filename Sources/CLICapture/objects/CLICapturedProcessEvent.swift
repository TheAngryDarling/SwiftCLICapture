//
//  CLICapturedProcessEvent.swift
//  
//
//  Created by Tyler Anger on 2022-04-06.
//

import Foundation

/// An object that stores a captured Process event (Termination event or Output event)
public enum CLICapturedProcessEvent<DATA: CLICapturedData> {
    case output(CLICapturedOutputEvent<DATA>)
    case terminated(Process)
    
    /// The process the event occured on
    public var process: Process {
        switch self {
            case .output(let dta):
                return dta.process
            case .terminated(let rtn):
                return rtn
        }
    }
    
    /// Indicator if this is the process terminated event
    public var hasTerminated: Bool {
        guard case .terminated(_) = self else {
            return false
        }
        return true
    }
    /// Indicator if this is an output event
    public var isOutputEvent: Bool {
        guard case .output(_) = self else {
            return false
        }
        return true
    }
    /// The output event object
    public var outputEvent: CLICapturedOutputEvent<DATA>? {
        guard case .output(let rtn) = self else {
            return nil
        }
        return rtn
    }
}

public extension CLICapturedProcessEvent {
    /// Create new output event with stdOut data
    static func out(data: DATA, error: Int32, process: Process) -> CLICapturedProcessEvent<DATA> {
        return .output(.out(data: data, error: error, process: process))
    }
    /// Create new output event with stdErr data
    static func err(data: DATA, error: Int32, process: Process) -> CLICapturedProcessEvent<DATA> {
        return .output(.err(data: data, error: error, process: process))
    }
}
