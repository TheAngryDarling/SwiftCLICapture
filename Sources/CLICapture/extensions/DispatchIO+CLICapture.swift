//
//  DispatchIO+CLIWCapture.swift
//  CLIWCapture
//
//  Created by Tyler Anger on 2022-02-27.
//

import Foundation
import Dispatch

internal extension DispatchIO {
    
    static var defaultMaxLength: Int {
        // 3KB
        return (1024 * 3)
    }
    /// Schedules continious asynchronous read operations using the specified file descriptor.
    /// - Parameters:
    ///   - fromFileDescriptor: The file descriptor from which to read the data.
    ///   - maxLength: The maximum number of bytes to read from the channel. Specify SIZE_MAX to continue reading data until an EOF is reached.
    ///   - runningHandlerOn: The dispatch queue on which to submit the handler block.
    ///   - stopOnError: Indicator if reading should stop on error
    ///   - handler: The handler to execute once the channel is closed. This block has no return value and takes the following parameters:
    ///   - Parameters:
    ///     - data: A `DispatchData` object containing the data read from the file descriptor.
    ///     - error: An errno condition if there was an error; otherwise, the value is 0.
    static func continiousRead(fromFileDescriptor: Int32,
                               maxLength: Int = DispatchIO.defaultMaxLength,
                               runningHandlerOn: DispatchQueue,
                               stopOnError: Bool = true,
                               handler: @escaping (_ data: DispatchData,
                                                   _ error: Int32) -> Void) {
        
        
        #if os(macOS) //swift(>=5.0)
        
        DispatchIO.read(fromFileDescriptor: fromFileDescriptor,
                        maxLength: maxLength,
                        runningHandlerOn: runningHandlerOn) { data, err in
            handler(data, err)
            if  data.count > 0 &&
                (err == 0 || !stopOnError) {
                DispatchIO.continiousRead(fromFileDescriptor: fromFileDescriptor,
                                          maxLength: maxLength,
                                          runningHandlerOn: runningHandlerOn,
                                          stopOnError: stopOnError,
                                          handler: handler)
            }
        }
        #else
            DispatchQueue(label: "Read[\(fromFileDescriptor)]").async {
                var stop: Bool = false
                let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxLength)
                #if swift(>=4.1)
                pointer.initialize(repeating: 0, count: maxLength)
                #else
                pointer.initialize(to: 0, count: maxLength)
                #endif
                
                defer {
                    pointer.deinitialize(count: maxLength)
                    #if swift(>=4.1)
                    pointer.deallocate()
                    #endif
                }
                
                while !stop {
                    #if os(Linux)
                    let readSize = Glibc.read(fromFileDescriptor, pointer, maxLength)
                    #else
                    let readSize = Darwin.read(fromFileDescriptor, pointer, maxLength)
                    #endif
                    let err = errno
                    runningHandlerOn.sync {
                        let bufferPointer = UnsafeBufferPointer(start: pointer, count: readSize)
                        let rawBufferPointer = UnsafeRawBufferPointer(bufferPointer)
                        //let data = DispatchData(bytesNoCopy: rawBufferPointer,
                        //                        deallocator: .custom(nil, { })) // No deallocator because we reuse the buffer
                        let data = DispatchData(bytes: rawBufferPointer)
                        handler(data, err)
                    }
                    
                    if readSize == 0 ||
                        (err != 0 && !stopOnError) {
                        stop = true
                    }
                }
                
            }
        #endif
    }
    
    /// Schedules continious asynchronous read operations using the specified file descriptor.
    /// - Parameters:
    ///   - pipe: The file handle to read from
    ///   - maxLength: The maximum number of bytes to read from the channel. Specify SIZE_MAX to continue reading data until an EOF is reached.
    ///   - runningHandlerOn: The dispatch queue on which to submit the handler block.
    ///   - stopOnError: Indicator if reading should stop on error
    ///   - handler: The handler to execute once the channel is closed. This block has no return value and takes the following parameters:
    ///
    ///         data: A DispatchData object containing the data read from the file descriptor.
    ///         error: An errno condition if there was an error; otherwise, the value is 0.
    static func continiousRead(from fileHandle: FileHandle,
                               maxLength: Int = DispatchIO.defaultMaxLength,
                               runningHandlerOn: DispatchQueue,
                               stopOnError: Bool = true,
                               handler: @escaping (_ data: DispatchData,
                                                   _ error: Int32) -> Void) {
        DispatchIO.continiousRead(fromFileDescriptor: fileHandle.fileDescriptor,
                                  maxLength: maxLength,
                                  runningHandlerOn: runningHandlerOn,
                                  stopOnError: stopOnError,
                                  handler: handler)
        
    }
    
    /// Schedules continious asynchronous read operations using the specified file descriptor.
    /// - Parameters:
    ///   - pipe: The pipe containing the fileHandleForReading to read from
    ///   - maxLength: The maximum number of bytes to read from the channel. Specify SIZE_MAX to continue reading data until an EOF is reached.
    ///   - runningHandlerOn: The dispatch queue on which to submit the handler block.
    ///   - stopOnError: Indicator if reading should stop on error
    ///   - handler: The handler to execute once the channel is closed. This block has no return value and takes the following parameters:
    ///
    ///         data: A DispatchData object containing the data read from the file descriptor.
    ///         error: An errno condition if there was an error; otherwise, the value is 0.
    static func continiousRead(from pipe: Pipe,
                               maxLength: Int = DispatchIO.defaultMaxLength,
                               runningHandlerOn: DispatchQueue,
                               stopOnError: Bool = true,
                               handler: @escaping (_ data: DispatchData,
                                                   _ error: Int32) -> Void) {
        DispatchIO.continiousRead(from: pipe.fileHandleForReading,
                                  maxLength: maxLength,
                                  runningHandlerOn: runningHandlerOn,
                                  stopOnError: stopOnError,
                                  handler: handler)
        
    }
}
