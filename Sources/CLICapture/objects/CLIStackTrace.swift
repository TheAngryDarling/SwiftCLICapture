//
//  CLIStackTrace.swift
//  
//
//  Created by Tyler Anger on 2022-07-19.
//

import Foundation
/// Object used to keep track of stack trace items when calling CLICapture functions
public struct CLIStackTrace: BidirectionalCollection {
    /// A stack trace item which contains the path to the file, the calling function and the line
    public struct StackItem: CustomStringConvertible {
        public let filePath: String
        public let function: String
        public let line: UInt
        
        public var functionName: String {
            guard let r = self.function.range(of: "(") else {
                return self.function
            }
            return String(self.function[..<r.lowerBound])
        }
        
        
        public var description: String {
            return "\(self.filePath):\(self.line) - \(self.function)"
        }
        
        public init(filePath: StaticString,
                    function: StaticString,
                    line: UInt) {
            self.filePath = "\(filePath)"
            self.function = "\(function)"
            self.line = line
        }
    }
    
    private var mutable: Bool
    private var stack: [StackItem]
    
    public var startIndex: Int { return self.stack.startIndex }
    public var endIndex: Int { return self.stack.endIndex }
    
    public subscript(position: Int) -> StackItem {
        return self.stack[position]
    }
    
    /// Copy the given stack trace and keep its locking flag
    /// - Parameters:
    ///   - locked: Override the locking flag of the stack trace to copy
    ///   - stackTrace: The stack trace to copy
    public init(locked: Bool, copying stackTrace: CLIStackTrace) {
        self.mutable = !locked
        self.stack = stackTrace.stack
    }
    
    /// Copy the given stack trace and keep its locking flag
    /// - Parameter stackTrace: The stack trace to copy
    public init(copying stackTrace: CLIStackTrace) {
        self.init(locked: !stackTrace.mutable, copying: stackTrace)
    }
    
    /// Stack a new stack item to the list if the stack trace is unlocked
    /// - Parameter item: The item to stack
    public mutating func stack(_ item: StackItem) {
        if self.mutable {
            self.stack.insert(item, at: 0)
        }
    }
    
    /// Create a copy of the of the current stack trace and stack the new stack item
    /// - Parameters:
    ///   - item: The item to stack
    ///   - locked: optional bool to set the lockable flag of the new stack trace before stacking the new item
    /// - Returns: Retruns the new stack trace
    public func stacking(_ item: StackItem, locked: Bool? = nil) -> CLIStackTrace {
        var rtn = CLIStackTrace(copying: self)
        if let l = locked { rtn.mutable = !l }
        rtn.stack(item)
        return rtn
    }
    
    
    public func index(after position: Int) -> Int {
        return self.stack.index(after: position)
    }
    
    public func index(before position: Int) -> Int {
        return self.stack.index(before: position)
    }
    
    #if swift(>=5.3)
    /// Create new Stack Trace
    /// - Parameters:
    ///   - locked: Indicator if the stack trace is locked an no other stack trace items can be appended
    ///   - filePath: The calling file
    ///   - function: The calling function
    ///   - line: The calling line
    public init(locked: Bool = false,
                filePath: StaticString = #filePath,
                function: StaticString = #function,
                line: UInt = #line) {
        self.mutable = !locked
        self.stack = [.init(filePath: filePath, function: function, line: line)]
    }
    
    /// Add new stack item to the stack trace
    /// - Parameters:
    ///   - filePath: The calling file
    ///   - function: The calling function
    ///   - line: The calling line
    public mutating func stack(filePath: StaticString = #filePath,
                               function: StaticString = #function,
                               line: UInt = #line) {
        self.stack(.init(filePath: filePath, function: function, line: line))
    }
    
    /// Create a copy of the given stack trace and add a new stack item if the stack trace is not locked
    /// - Parameters:
    ///   - filePath: The calling file
    ///   - function: The calling function
    ///   - line: The calling line
    ///   - locked: optional bool to set the lockable flag of the new stack trace before stacking the new item
    /// - Returns: Returns new stack trace
    public func stacking(filePath: StaticString = #filePath,
                         function: StaticString = #function,
                         line: UInt = #line,
                         locked: Bool? = nil) -> CLIStackTrace {
        
        return self.stacking(.init(filePath: filePath, function: function, line: line),
                             locked: locked)
    }
    
    #else
    /// Create new Stack Trace
    /// - Parameters:
    ///   - locked: Indicator if the stack trace is locked an no other stack trace items can be appended
    ///   - filePath: The calling file
    ///   - function: The calling function
    ///   - line: The calling line
    public init(locked: Bool = false,
                filePath: StaticString = #file,
                function: StaticString = #function,
                line: UInt = #line) {
        self.mutable = !locked
        self.stack = [.init(filePath: filePath, function: function, line: line)]
    }
    
    /// Add new stack item to the stack trace
    /// - Parameters:
    ///   - filePath: The calling file
    ///   - function: The calling function
    ///   - line: The calling line
    public mutating func stack(filePath: StaticString = #file,
                               function: StaticString = #function,
                               line: UInt = #line) {
        self.stack(.init(filePath: filePath, function: function, line: line))
    }
    
    /// Create a copy of the given stack trace and add a new stack item if the stack trace is not locked
    /// - Parameters:
    ///   - filePath: The calling file
    ///   - function: The calling function
    ///   - line: The calling line
    ///   - locked: optional bool to set the lockable flag of the new stack trace before stacking the new item
    /// - Returns: Returns new stack trace
    public func stacking(filePath: StaticString = #file,
                         function: StaticString = #function,
                         line: UInt = #line,
                         locked: Bool? = nil) -> CLIStackTrace {
        
        return self.stacking(.init(filePath: filePath, function: function, line: line),
                             locked: locked)
    }
    #endif
    
}
