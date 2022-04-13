//
//  CLICapture.swift
//
//
//  Created by Tyler Anger on 2022-03-25.
//

import Foundation
import Dispatch
import SynchronizeObjects

/// Object used to execute and/or capture output from a CLI process
open class CLICapture {
    /// CLICapture specific errors
    public enum CLIError: Swift.Error {
        /// The CLI Process failed to complete in the specified time
        case procesTimeout(Process)
    }
    
    /// A Data buffer used to collect any
    /// Data that should be going to STD Out or STD Err
    ///
    /// Primary purpose of this object is for testing
    public class STDBuffer {
        internal enum Stream {
            case out
            case err
        }
        private var  data: Data
        private let lock = NSLock()
        
        public init() { self.data = Data() }
        
        /// Empty buffer
        public func empty() {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            if self.data.count > 0 {
                self.data.removeAll()
            }
        }
        /// Read any data in the buffer and clear buffer
        public func readBuffer() -> Data {
            self.lock.lock()
            defer {
                self.data = Data()
                self.lock.unlock()
            }
            return self.data
        }
        
        internal func append<S>(_ data: S,
                                to stream: Stream) where S: Sequence, S.Element == UInt8 {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            self.data.append(contentsOf: data)
        }
        
    }
    
    /// A Data buffer used to collect any
    /// Data that should be going to STD Out AND STD Err
    ///
    /// Primary purpose of this object is for testing
    public class STDOutputBuffer: STDBuffer {
        
        public let out: STDBuffer
        public let err: STDBuffer
        
        public override init() {
            self.out = STDBuffer()
            self.err = STDBuffer()
            super.init()
        }
        /// Read any data in the buffer and clear buffer
        /// - Parameter emptyAll: Indicator if STD Out and STD Err buffers should be emptied as well
        /// - Returns: Returns any data currently buffered
        public func readBuffer(emptyAll: Bool) -> Data {
            if emptyAll {
                self.out.empty()
                self.err.empty()
            }
            return super.readBuffer()
        }
        
        public override func readBuffer() -> Data {
            return self.readBuffer(emptyAll: true)
        }
        
        /// Empty buffer
        /// - Parameter all: Indicator if STD Out and STD Err buffers should be emptied as well
        public func empty(all: Bool) {
            if all {
                self.out.empty()
                self.err.empty()
            }
            super.empty()
        }
        
        public override func empty() {
            self.empty(all: true)
        }
        
        override internal func append<S>(_ data: S,
                                         to stream: Stream) where S: Sequence, S.Element == UInt8 {
            switch stream {
                case .out:
                    self.out.append(data, to: stream)
                case .err:
                    self.err.append(data, to: stream)
            }
            super.append(data, to: stream)
        }
        
    }
    
    /// Closure used to create a new CLI Process
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    public typealias CreateProcess = (_ arguments: [String],
                                      _ environment: [String: String]?,
                                      _ currentDirectory: URL?,
                                      _ standardInput: Any?) -> Process
    
    
    /// Event Handler for capturing events from a Process
    public typealias CapturedProcessEventHandler<DATA> = (_ event: CLICapturedProcessEvent<DATA>) -> Void where DATA: CLICapturedData
    
    /// Event handler for capturing Data Events from a Process
    public typealias CapturedOutputEventHandler<DATA> = (_ event: CLICapturedOutputEvent<DATA>) -> Void where DATA: CLICapturedData
    
    
    /// Buffer used to capture what should be going to STDOUT
    internal var stdOutBuffer: STDBuffer? = nil
    /// Buffer used to capture what should be going to STDERR
    internal var stdErrBuffer: STDBuffer? = nil
    /// Dispatch Queue used to handle events comming from writing to STD Outputs
    private let writeQueue = DispatchQueue(label: "CLICapture.STDOutput.write")
    
    /// The object used to synchronized output calls
    public let outputLock: Lockable
    
    /// The closure used to create a new CLI process
    public let createProcess: CreateProcess
    
    /// Create a new CLI Capture object
    /// - Parameters:
    ///   - outputLock: The object used to synchronized output calls
    ///   - stdOutBuffer: The buffer to redirect any STDOut writes to
    ///   - stdErrBuffer: The buffer to redirect any STDErr writes to
    ///   - createProcess: The closure used to create a new CLI process
    public init(outputLock: Lockable = NSLock(),
                stdOutBuffer: STDBuffer? = nil,
                stdErrBuffer: STDBuffer? = nil,
                createProcess: @escaping CreateProcess) {
        self.outputLock = outputLock
        self.stdOutBuffer = stdOutBuffer
        self.stdErrBuffer = stdErrBuffer
        self.createProcess = createProcess
    }
    
    /// Create a new CLI Capture object
    /// - Parameters:
    ///   - outputQueue: The dispatch queue to use when passing data back to the output
    ///   - stdOutBuffer: The buffer to redirect any STDOut writes to
    ///   - stdErrBuffer: The buffer to redirect any STDErr writes to
    ///   - createProcess: The closure used to create a new CLI process
    public init(outputQueue: DispatchQueue,
                stdOutBuffer: STDBuffer? = nil,
                stdErrBuffer: STDBuffer? = nil,
                createProcess: @escaping CreateProcess) {
        self.outputLock = outputQueue
        self.stdOutBuffer = stdOutBuffer
        self.stdErrBuffer = stdErrBuffer
        self.createProcess = createProcess
    }
    
    
    /// Create a new CLI Capture object
    /// - Parameters:
    ///   - outputLock: The object used to synchronized output calls
    ///   - stdOutBuffer: The buffer to redirect any STDOut writes to
    ///   - stdErrBuffer: The buffer to redirect any STDErr writes to
    ///   - executable: The URL to the executable to use
    public init(outputLock: Lockable = NSLock(),
                stdOutBuffer: STDBuffer? = nil,
                stdErrBuffer: STDBuffer? = nil,
                executable: URL) {
        self.outputLock = outputLock
        self.stdOutBuffer = stdOutBuffer
        self.stdErrBuffer = stdErrBuffer
        self.createProcess = {
            (_ arguments: [String],
             _ environment: [String: String]?,
             _ currentDirectory: URL?,
             _ standardInput: Any?) -> Process in
            
            let rtn = Process()
            rtn._cliCaptureExecutable = executable
            rtn.arguments = arguments
            if let env = environment {
                rtn.environment = env
            }
            if let cd = currentDirectory {
                rtn._cliCaptureCurrentDirectory = cd
            }
            if let si = standardInput {
                rtn.standardInput = si
            }
            return rtn
        }
    }
    
    /// Create a new CLI Capture object
    /// - Parameters:
    ///   - outputQueue: The dispatch queue to use when passing data back to the output
    ///   - stdOutBuffer: The buffer to redirect any STDOut writes to
    ///   - stdErrBuffer: The buffer to redirect any STDErr writes to
    ///   - executable: The URL to the executable to use
    public init(outputQueue: DispatchQueue,
                stdOutBuffer: STDBuffer? = nil,
                stdErrBuffer: STDBuffer? = nil,
                executable: URL) {
        self.outputLock = outputQueue
        self.stdOutBuffer = stdOutBuffer
        self.stdErrBuffer = stdErrBuffer
        self.createProcess = {
            (_ arguments: [String],
             _ environment: [String: String]?,
             _ currentDirectory: URL?,
             _ standardInput: Any?) -> Process in
            
            let rtn = Process()
            rtn._cliCaptureExecutable = executable
            rtn.arguments = arguments
            if let env = environment {
                rtn.environment = env
            }
            if let cd = currentDirectory {
                rtn._cliCaptureCurrentDirectory = cd
            }
            if let si = standardInput {
                rtn.standardInput = si
            }
            return rtn
        }
    }
    
    /// Method used to write data to the STD Out or outBuffer is set
    fileprivate func writeDataToOut(_ data: DispatchData) {
        self.outputLock.lockingFor {
            if let b = self.stdOutBuffer {
                b.append(data, to: .out)
            } else {
                DispatchIO.writeAllAndWait(toFileDescriptor: STDOUT_FILENO,
                                           data: data)
                
                fflush(stdout)
                fsync(STDOUT_FILENO)
            }
        }
    }
    /// Method used to write data to the STD Err or errBuffer is set
    fileprivate func writeDataToErr(_ data: DispatchData) {
        self.outputLock.lockingFor {
            if let b = self.stdErrBuffer {
                b.append(data, to: .err)
            } else {
                DispatchIO.writeAllAndWait(toFileDescriptor: STDERR_FILENO,
                                           data: data)
                fflush(stderr)
                fsync(STDERR_FILENO)
            }
        }
    }
    
    /// Execute the CLI process and capture output events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass Process events to
    /// - Returns: Returns the process being executed
    open func capture<ARGS, DATA>(arguments: ARGS,
                                    environment: [String: String]? = nil,
                                    currentDirectory: URL? = nil,
                                    standardInput: Any? = nil,
                                    outputOptions: CLIOutputOptions = .all,
                                    runningEventHandlerOn: DispatchQueue? = nil,
                                    eventHandler: @escaping CapturedProcessEventHandler<DATA>) throws -> Process
    where ARGS: Sequence, ARGS.Element == String {
        
        let process = self.createProcess(((arguments as? [String]) ?? Array<String>(arguments)),
                              environment,
                              currentDirectory,
                              standardInput)
        
        /*
        var cmd = process.executable!.path
        for arg in (process.arguments ?? []) {
            cmd += " " + arg
        }
        print("Capturing: \(outputOptions)")
        print(cmd)
        */
        var pipes: [Pipe] = []
            
        let eventQueue = runningEventHandlerOn ?? DispatchQueue(label: "CLICapture.ExecuteCLICommand")
        
        
        var outReadFinished: Bool = true
        var errReadFinished: Bool = true
        
        if outputOptions.capture.contains(.out) || self.stdOutBuffer != nil {
            outReadFinished = false
            let outPipe = Pipe()
            pipes.append(outPipe)
            process.standardOutput = outPipe
            DispatchIO.continiousRead(from: outPipe,
                                      runningHandlerOn: eventQueue) { data, err in
                if outputOptions.passthrough.contains(.out) {
                    self.writeDataToOut(data)
                }
                if outputOptions.capture.contains(.out) {
                    eventHandler(.out(data: (data as? DATA) ?? DATA(data),
                                      error: err,
                                      process: process))
                }
                
                outReadFinished = (err != 0 || (err == 0 && data.count == 0))
                //print("Finished Read STD Out: \(errReadFinished)")
            }
        } else if !outputOptions.passthrough.contains(.out) {
            #if os(macOS) || swift(>=5.0)
            process.standardOutput = FileHandle.nullDevice
            #else
            let p = Pipe()
            pipes.append(p)
            process.standardOutput = p
            #endif
        }
        
        
        if outputOptions.capture.contains(.err) || self.stdErrBuffer != nil {
            errReadFinished = false
            let errPipe = Pipe()
            pipes.append(errPipe)
            process.standardError = errPipe
            DispatchIO.continiousRead(from: errPipe,
                                      runningHandlerOn: eventQueue) { data, err in
                if outputOptions.passthrough.contains(.err) {
                    self.writeDataToErr(data)
                }
                
                if outputOptions.capture.contains(.err) {
                    eventHandler(.err(data: (data as? DATA) ?? DATA(data),
                                      error: err,
                                      process: process))
                }
                
                errReadFinished = (err != 0 || (err == 0 && data.count == 0))
                //print("Finished Read STD Err: \(errReadFinished)")
            }
        } else if !outputOptions.passthrough.contains(.err) {
            #if os(macOS) || swift(>=5.0)
            process.standardError = FileHandle.nullDevice
            #else
            let p = Pipe()
            pipes.append(p)
            process.standardError = p
            #endif
        }
            
        
        process.terminationHandler = { process in
            // Waiting to make sure DispatchIO reads are finished
            while !(outReadFinished && errReadFinished) {
                //print("Waiting fo events to end")
                Thread.sleep(forTimeInterval: 0.05)
            }
            // Clean up pipes
            for pipe in pipes {
                pipe.fileHandleForReading.closeFile()
                pipe.fileHandleForWriting.closeFile()
            }
            
            // Signal event handler
            eventQueue.async {
                eventHandler(.terminated(process))
            }
        }
            
        try process._cliCaptureExecute()
        
        return process
    }
    
    /// Execute the core process
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - passthrougOptions: The passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - callbackHandler: The handler to call when the process has finished
    /// - Returns: Returns the process being executed
    open func execute<ARGS>(arguments: ARGS,
                            environment: [String: String]? = nil,
                            currentDirectory: URL? = nil,
                            standardInput: Any? = nil,
                            passthrougOptions: CLIPassthroughOptions = .all,
                            runningCallbackHandlerOn: DispatchQueue? = nil,
                            callbackHandler: @escaping(_ sender: Process) -> Void) throws -> Process
        where ARGS: Sequence, ARGS.Element == String {
        
        func emptyEventCapture(_ event: CLICapturedProcessEvent<DispatchData>) {
            if event.hasTerminated {
                callbackHandler(event.process)
            }
        }
        
        return try self.capture(arguments: arguments,
                                environment: environment,
                                currentDirectory: currentDirectory,
                                standardInput: standardInput,
                                outputOptions: CLIOutputOptions.none + passthrougOptions,
                                runningEventHandlerOn: runningCallbackHandlerOn,
                                eventHandler: emptyEventCapture)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    open func captureResponse<ARGS,
                              EventData,
                              CapturedData,
                              CapturedResponse>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                responseParser: @escaping (_ exitStatusCode: Int32,
                                                                           _ captureOptions: CLICaptureOptions,
                                                                           _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                                callbackHandler: @escaping (_ sender: Process,
                                                                            _ response: CapturedResponse?,
                                                                            _ error: Swift.Error?) -> Void) throws -> Process
        where ARGS: Sequence,
              ARGS.Element == String {
                  
      var output: [CLICapturedOutputEvent<CapturedData>] = []
      func dataEventHandler(_ event: CLICapturedProcessEvent<CapturedData>) {
          if let o = event.outputEvent {
              output.append(o)
              let evt = CLICapturedOutputEvent<EventData>(o) //(event as? CLICapturedOutputEvent<EventData>) ?? CLICapturedOutputEvent(event)
              
              eventHandler(evt)
          } else if event.hasTerminated {
              do {
                  callbackHandler(event.process,
                                  try responseParser(event.process.terminationStatus,
                                                     outputOptions.capture,
                                                     output),
                                  nil)
              } catch {
                  callbackHandler(event.process, nil, error)
              }
          }
          
      }
          
      return try self.capture(arguments: arguments,
                              environment: environment,
                              currentDirectory: currentDirectory,
                              standardInput: standardInput,
                              outputOptions: outputOptions,
                              runningEventHandlerOn: runningEventHandlerOn,
                              eventHandler: dataEventHandler)
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseType: The type of object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    open func captureResponse<ARGS,
                              EventData,
                              CapturedResponse>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                withResponseType responseType: CapturedResponse.Type,
                                                callbackHandler: @escaping (_ sender: Process,
                                                                            _ response: CapturedResponse?,
                                                                            _ error: Swift.Error?) -> Void) throws -> Process
        where ARGS: Sequence,
              ARGS.Element == String,
              CapturedResponse: CLICapturedResponse {
                  
        func responseParser(_ exitStatusCode: Int32,
                            _ captureOptions: CLICaptureOptions,
                            _ capturedEvents: [CLICapturedOutputEvent<DispatchData>]) throws -> CapturedResponse {
            return try CapturedResponse.init(exitStatusCode: exitStatusCode,
                                             captureOptions: captureOptions,
                                             capturedEvents: capturedEvents)
        }
                  
        return try self.captureResponse(arguments: arguments,
                                      environment: environment,
                                      currentDirectory: currentDirectory,
                                      standardInput: standardInput,
                                      outputOptions: outputOptions,
                                      eventHandler: eventHandler,
                                      responseParser: responseParser,
                                      callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - dataType: The type of data object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedDataResponse object
    /// - Returns: Returns the process being executed
    open func captureDataResponse<ARGS,
                                  EventData,
                                  ResponseData>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                withDataType dataType: ResponseData.Type,
                                                callbackHandler: @escaping (_ sender: Process,
                                                                            _ response: CLICapturedDataResponse<ResponseData>?,
                                                                            _ error: Swift.Error?) -> Void ) throws -> Process
    where ARGS: Sequence, ARGS.Element == String {
        return try self.captureResponse(arguments: arguments,
                                        environment: environment,
                                        currentDirectory: currentDirectory,
                                        standardInput: standardInput,
                                        outputOptions: outputOptions,
                                        runningEventHandlerOn: runningEventHandlerOn,
                                        eventHandler: eventHandler,
                                        withResponseType: CLICapturedDataResponse<ResponseData>.self,
                                        callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedStringResponse object
    /// - Returns: Returns the process being executed
    open func captureStringResponse<ARGS,
                                    EventData>(arguments: ARGS,
                                               environment: [String: String]? = nil,
                                               currentDirectory: URL? = nil,
                                               standardInput: Any? = nil,
                                               outputOptions: CLIOutputOptions = .captureAll,
                                               runningEventHandlerOn: DispatchQueue? = nil,
                                               eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                callbackHandler: @escaping (_ sender: Process,
                                                                            _ response: CLICapturedStringResponse?,
                                                                            _ error: Swift.Error?) -> Void ) throws -> Process
        where ARGS: Sequence, ARGS.Element == String {
            
        return try self.captureResponse(arguments: arguments,
                                        environment: environment,
                                        currentDirectory: currentDirectory,
                                        standardInput: standardInput,
                                        outputOptions: outputOptions,
                                        runningEventHandlerOn: runningEventHandlerOn,
                                        eventHandler: eventHandler,
                                        withResponseType: CLICapturedStringResponse.self,
                                        callbackHandler: callbackHandler)
    
    }
}

// MARK: Without 'eventHandler' Parameter(s)

public extension CLICapture {
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    func captureResponse<ARGS,
                         CapturedData,
                         CapturedResponse>(arguments: ARGS,
                                           environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningCallbackHandlerOn: DispatchQueue? = nil,
                                           responseParser: @escaping (_ exitStatusCode: Int32,
                                                                      _ captureOptions: CLICaptureOptions,
                                                                      _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CapturedResponse?,
                                                                       _ error: Swift.Error?) -> Void) throws -> Process
    where ARGS: Sequence,
          ARGS.Element == String {
                  
              func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
            
              return try self.captureResponse(arguments: arguments,
                                              environment: environment,
                                              currentDirectory: currentDirectory,
                                              standardInput: standardInput,
                                              outputOptions: outputOptions,
                                              runningEventHandlerOn: runningCallbackHandlerOn,
                                              eventHandler: eventHandler,
                                              responseParser: responseParser,
                                              callbackHandler: callbackHandler)
      
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - responseType: The type of object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    func captureResponse<ARGS,
                         CapturedResponse>(arguments: ARGS,
                                           environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningCallbackHandlerOn: DispatchQueue? = nil,
                                           withResponseType responseType: CapturedResponse.Type,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CapturedResponse?,
                                                                       _ error: Swift.Error?) -> Void) throws -> Process
        where ARGS: Sequence,
              ARGS.Element == String,
              CapturedResponse: CLICapturedResponse {
                  
          func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
        
          return try self.captureResponse(arguments: arguments,
                                          environment: environment,
                                          currentDirectory: currentDirectory,
                                          standardInput: standardInput,
                                          outputOptions: outputOptions,
                                          runningEventHandlerOn: runningCallbackHandlerOn,
                                          eventHandler: eventHandler,
                                          withResponseType: responseType,
                                          callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - dataType: The type of data object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedDataResponse object
    /// - Returns: Returns the process being executed
    func captureDataResponse<ARGS,
                             ResponseData>(arguments: ARGS,
                                           environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningCallbackHandlerOn: DispatchQueue? = nil,
                                           withDataType dataType: ResponseData.Type,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CLICapturedDataResponse<ResponseData>?,
                                                                        _ error: Swift.Error?) -> Void ) throws -> Process
    where ARGS: Sequence, ARGS.Element == String {
        func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
      
        return try self.captureDataResponse(arguments: arguments,
                                            environment: environment,
                                            currentDirectory: currentDirectory,
                                            standardInput: standardInput,
                                            outputOptions: outputOptions,
                                            runningEventHandlerOn: runningCallbackHandlerOn,
                                            eventHandler: eventHandler,
                                            withDataType: dataType,
                                            callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedStringResponse object
    /// - Returns: Returns the process being executed
    func captureStringResponse<ARGS>(arguments: ARGS,
                                     environment: [String: String]? = nil,
                                     currentDirectory: URL? = nil,
                                     standardInput: Any? = nil,
                                     outputOptions: CLIOutputOptions = .captureAll,
                                     runningCallbackHandlerOn: DispatchQueue? = nil,
                                     callbackHandler: @escaping (_ sender: Process,
                                                                 _ response: CLICapturedStringResponse?,
                                                                 _ error: Swift.Error?) -> Void ) throws -> Process
        where ARGS: Sequence, ARGS.Element == String {
            
            func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
          
            return try self.captureStringResponse(arguments: arguments,
                                                environment: environment,
                                                currentDirectory: currentDirectory,
                                                standardInput: standardInput,
                                                outputOptions: outputOptions,
                                                runningEventHandlerOn: runningCallbackHandlerOn,
                                                eventHandler: eventHandler,
                                                callbackHandler: callbackHandler)
    
    }
}

// MARK: Without 'arguments' Parameter
public extension CLICapture {
    
    /// Execute the CLI process and capture output events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    /// - Returns: Returns the process being executed
    func capture<DATA>(environment: [String: String]? = nil,
                       currentDirectory: URL? = nil,
                       standardInput: Any? = nil,
                       outputOptions: CLIOutputOptions = .all,
                       runningEventHandlerOn: DispatchQueue? = nil,
                       eventHandler: @escaping CapturedProcessEventHandler<DATA>) throws -> Process {
        return try self.capture(arguments: Array<String>(),
                                environment: environment,
                                currentDirectory: currentDirectory,
                                standardInput: standardInput,
                                outputOptions: outputOptions,
                                runningEventHandlerOn: runningEventHandlerOn,
                                eventHandler: eventHandler)
    }
    
    /// Execute the core process
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - passthrougOptions: The passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - callbackHandler: The handler to call when the process has finished
    /// - Returns: Returns the process being executed
    func execute(environment: [String: String]? = nil,
                 currentDirectory: URL? = nil,
                 standardInput: Any? = nil,
                 passthrougOptions: CLIPassthroughOptions = .all,
                 runningCallbackHandlerOn: DispatchQueue? = nil,
                 callbackHandler: @escaping(_ sender: Process) -> Void) throws -> Process {
        return try self.execute(arguments: Array<String>(),
                                environment: environment,
                                currentDirectory: currentDirectory,
                                standardInput: standardInput,
                                passthrougOptions: passthrougOptions,
                                runningCallbackHandlerOn: runningCallbackHandlerOn,
                                callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    func captureResponse<EventData,
                         CapturedData,
                         CapturedResponse>(environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningEventHandlerOn: DispatchQueue? = nil,
                                           eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                           responseParser: @escaping (_ exitStatusCode: Int32,
                                                                      _ captureOptions: CLICaptureOptions,
                                                                      _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CapturedResponse?,
                                                                       _ error: Swift.Error?) -> Void) throws -> Process {
                  
        return try self.captureResponse(arguments: Array<String>(),
                                        environment: environment,
                                        currentDirectory: currentDirectory,
                                        standardInput: standardInput,
                                        outputOptions: outputOptions,
                                        runningEventHandlerOn: runningEventHandlerOn,
                                        eventHandler: eventHandler,
                                        responseParser: responseParser,
                                        callbackHandler: callbackHandler)
        
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseType: The type of object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    func captureResponse<EventData,
                         CapturedResponse>(environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningEventHandlerOn: DispatchQueue? = nil,
                                           eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                           withResponseType responseType: CapturedResponse.Type,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CapturedResponse?,
                                                                       _ error: Swift.Error?) -> Void) throws -> Process
        where CapturedResponse: CLICapturedResponse {
                  
        return try self.captureResponse(arguments: Array<String>(),
                                        environment: environment,
                                        currentDirectory: currentDirectory,
                                        standardInput: standardInput,
                                        outputOptions: outputOptions,
                                        runningEventHandlerOn: runningEventHandlerOn,
                                        eventHandler: eventHandler,
                                        withResponseType: responseType,
                                        callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - dataType: The type of data object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedDataResponse object
    /// - Returns: Returns the process being executed
    func captureDataResponse<EventData,
                             ResponseData>(environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningEventHandlerOn: DispatchQueue? = nil,
                                           eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                           withDataType dataType: ResponseData.Type,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CLICapturedDataResponse<ResponseData>?,
                                                                       _ error: Swift.Error?) -> Void ) throws -> Process {
        return try self.captureDataResponse(arguments: Array<String>(),
                                            environment: environment,
                                            currentDirectory: currentDirectory,
                                            standardInput: standardInput,
                                            outputOptions: outputOptions,
                                            runningEventHandlerOn: runningEventHandlerOn,
                                            eventHandler: eventHandler,
                                            withDataType: dataType,
                                            callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedStringResponse object
    /// - Returns: Returns the process being executed
    func captureStringResponse<EventData>(environment: [String: String]? = nil,
                                          currentDirectory: URL? = nil,
                                          standardInput: Any? = nil,
                                          outputOptions: CLIOutputOptions = .captureAll,
                                          runningEventHandlerOn: DispatchQueue? = nil,
                                          eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                          callbackHandler: @escaping (_ sender: Process,
                                                                      _ response: CLICapturedStringResponse?,
                                                                      _ error: Swift.Error?) -> Void ) throws -> Process {
            
        return try self.captureStringResponse(arguments: Array<String>(),
                                              environment: environment,
                                              currentDirectory: currentDirectory,
                                              standardInput: standardInput,
                                              outputOptions: outputOptions,
                                              runningEventHandlerOn: runningEventHandlerOn,
                                              eventHandler: eventHandler,
                                              callbackHandler: callbackHandler)
    
    }
    
}

// MARK: Without 'arguments' and 'eventHandler' Parameters
public extension CLICapture {
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    func captureResponse<CapturedData,
                         CapturedResponse>(environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningCallbackHandlerOn: DispatchQueue? = nil,
                                           responseParser: @escaping (_ exitStatusCode: Int32,
                                                                      _ captureOptions: CLICaptureOptions,
                                                                      _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CapturedResponse?,
                                                                       _ error: Swift.Error?) -> Void) throws -> Process {
        
        func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
                  
        return try self.captureResponse(arguments: Array<String>(),
                                        environment: environment,
                                        currentDirectory: currentDirectory,
                                        standardInput: standardInput,
                                        outputOptions: outputOptions,
                                        runningEventHandlerOn: runningCallbackHandlerOn,
                                        eventHandler: eventHandler,
                                        responseParser: responseParser,
                                        callbackHandler: callbackHandler)
        
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - responseType: The type of object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CapturedResponse object
    /// - Returns: Returns the process being executed
    func captureResponse<CapturedResponse>(environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningCallbackHandlerOn: DispatchQueue? = nil,
                                           withResponseType responseType: CapturedResponse.Type,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CapturedResponse?,
                                                                       _ error: Swift.Error?) -> Void) throws -> Process
    where CapturedResponse: CLICapturedResponse {
        
        func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
            
        return try self.captureResponse(arguments: Array<String>(),
                                        environment: environment,
                                        currentDirectory: currentDirectory,
                                        standardInput: standardInput,
                                        outputOptions: outputOptions,
                                        runningEventHandlerOn: runningCallbackHandlerOn,
                                        eventHandler: eventHandler,
                                        withResponseType: responseType,
                                        callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - dataType: The type of data object to containd the captured response
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedDataResponse object
    /// - Returns: Returns the process being executed
    func captureDataResponse<ResponseData>(environment: [String: String]? = nil,
                                           currentDirectory: URL? = nil,
                                           standardInput: Any? = nil,
                                           outputOptions: CLIOutputOptions = .captureAll,
                                           runningCallbackHandlerOn: DispatchQueue? = nil,
                                           withDataType dataType: ResponseData.Type,
                                           callbackHandler: @escaping (_ sender: Process,
                                                                       _ response: CLICapturedDataResponse<ResponseData>?,
                                                                       _ error: Swift.Error?) -> Void ) throws -> Process {
        
        func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
        
        return try self.captureDataResponse(arguments: Array<String>(),
                                            environment: environment,
                                            currentDirectory: currentDirectory,
                                            standardInput: standardInput,
                                            outputOptions: outputOptions,
                                            runningEventHandlerOn: runningCallbackHandlerOn,
                                            eventHandler: eventHandler,
                                            withDataType: dataType,
                                            callbackHandler: callbackHandler)
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - runningCallbackHandlerOn: The dispatch queue to call the event handler on
    ///   - callbackHandler: The closure to execute when capturing is finished with the CLICapturedStringResponse object
    /// - Returns: Returns the process being executed
    func captureStringResponse(environment: [String: String]? = nil,
                               currentDirectory: URL? = nil,
                               standardInput: Any? = nil,
                               outputOptions: CLIOutputOptions = .captureAll,
                               runningCallbackHandlerOn: DispatchQueue? = nil,
                               callbackHandler: @escaping (_ sender: Process,
                                                           _ response: CLICapturedStringResponse?,
                                                           _ error: Swift.Error?) -> Void ) throws -> Process {
            
        func eventHandler(_ event: CLICapturedOutputEvent<DispatchData>) -> Void { }
        
        return try self.captureStringResponse(arguments: Array<String>(),
                                              environment: environment,
                                              currentDirectory: currentDirectory,
                                              standardInput: standardInput,
                                              outputOptions: outputOptions,
                                              runningEventHandlerOn: runningCallbackHandlerOn,
                                              eventHandler: eventHandler,
                                              callbackHandler: callbackHandler)
    
    }
    
}

// MARK: waitAnd Methods
public extension CLICapture {
    
    /// Execute the CLI process and capture output events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass Process events to
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns terminationStatus of the process executed
    func waitAndCapture<ARGS, DATA>(arguments: ARGS,
                                    environment: [String: String]? = nil,
                                    currentDirectory: URL? = nil,
                                    standardInput: Any? = nil,
                                    outputOptions: CLIOutputOptions = .all,
                                    runningEventHandlerOn: DispatchQueue? = nil,
                                    eventHandler: @escaping CapturedOutputEventHandler<DATA>,
                                    timeout: DispatchTime = .distantFuture) throws -> Int32
    where ARGS: Sequence, ARGS.Element == String {
       
        let semaphore = DispatchSemaphore(value: 0)
        
        let p = try self.capture(arguments: arguments,
                                 environment: environment,
                                 currentDirectory: currentDirectory,
                                 standardInput: standardInput,
                                 outputOptions: outputOptions,
                                 runningEventHandlerOn: runningEventHandlerOn ) {
            (_ event: CLICapturedProcessEvent<DATA>) -> Void in
            
            if let o = event.outputEvent {
                eventHandler(o)
            } else {
                if event.hasTerminated {
                    semaphore.signal()
                }
            }
            
        }
                    
        guard semaphore.wait(timeout: timeout) == .success else {
            if p.isRunning {
                p.terminate()
            }
            throw CLIError.procesTimeout(p)
        }
        return p.terminationStatus
        
    }
    
    /// Execute the core process
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - passthrougOptions: The passthrough options for the core process outputs
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns terminationStatus of the process executed
    func executeAndWait<ARGS>(arguments: ARGS,
                              environment: [String: String]? = nil,
                              currentDirectory: URL? = nil,
                              standardInput: Any? = nil,
                              passthrougOptions: CLIPassthroughOptions = .all,
                              timeout: DispatchTime = .distantFuture) throws -> Int32
    where ARGS: Sequence, ARGS.Element == String {
        
        let semaphore = DispatchSemaphore(value: 0)
        let p = try self.execute(arguments: arguments,
                                 environment: environment,
                                 currentDirectory: currentDirectory,
                                 standardInput: standardInput,
                                 passthrougOptions: passthrougOptions,
                                 callbackHandler: { _ in semaphore.signal()})
        guard semaphore.wait(timeout: timeout) == .success else {
            if p.isRunning {
                p.terminate()
            }
            throw CLIError.procesTimeout(p)
        }
        return p.terminationStatus
        
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<ARGS,
                              EventData,
                              CapturedData,
                              CapturedResponse>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                responseParser: @escaping (_ exitStatusCode: Int32,
                                                                           _ captureOptions: CLICaptureOptions,
                                                                           _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                                timeout: DispatchTime = .distantFuture) throws -> CapturedResponse
    where ARGS: Sequence,
          ARGS.Element == String {
                  
        let semaphore = DispatchSemaphore(value: 0)
        var rtn: CapturedResponse? = nil
        var err: Swift.Error? = nil
        let p = try self.captureResponse(arguments: arguments,
                                         environment: environment,
                                         currentDirectory: currentDirectory,
                                         standardInput: standardInput,
                                         outputOptions: outputOptions,
                                         runningEventHandlerOn: runningEventHandlerOn,
                                         eventHandler: eventHandler,
                                         responseParser: responseParser) {
            (_ sender: Process, _ response: CapturedResponse?, _ error: Swift.Error?) -> Void in
            rtn = response
            err = error
            semaphore.signal()
            
        }
                            
        guard semaphore.wait(timeout: timeout) == .success else {
          if p.isRunning {
              p.terminate()
          }
          throw CLIError.procesTimeout(p)
        }
              
        if let e = err { throw e }
        return rtn!
              
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseType: The type of object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<ARGS,
                              EventData,
                              CapturedResponse>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                withResponseType responseType: CapturedResponse.Type,
                                                timeout: DispatchTime = .distantFuture) throws -> CapturedResponse
        where ARGS: Sequence,
              ARGS.Element == String,
              CapturedResponse: CLICapturedResponse {
                  
          let semaphore = DispatchSemaphore(value: 0)
          var rtn: CapturedResponse? = nil
          var err: Swift.Error? = nil
          let p = try self.captureResponse(arguments: arguments,
                                           environment: environment,
                                           currentDirectory: currentDirectory,
                                           standardInput: standardInput,
                                           outputOptions: outputOptions,
                                           runningEventHandlerOn: runningEventHandlerOn,
                                           eventHandler: eventHandler,
                                           withResponseType: responseType) {
              (_ sender: Process, _ response: CapturedResponse?, _ error: Swift.Error?) -> Void in
              rtn = response
              err = error
              semaphore.signal()
              
          }
                              
          guard semaphore.wait(timeout: timeout) == .success else {
            if p.isRunning {
                p.terminate()
            }
            throw CLIError.procesTimeout(p)
          }
                
          if let e = err { throw e }
          return rtn!
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - dataType: The type of data object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CLICapturedDataResponse object
    func waitAndCaptureDataResponse<ARGS,
                                  EventData,
                                  ResponseData>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                withDataType dataType: ResponseData.Type,
                                                timeout: DispatchTime = .distantFuture) throws -> CLICapturedDataResponse<ResponseData>
    where ARGS: Sequence, ARGS.Element == String {
        let semaphore = DispatchSemaphore(value: 0)
        var rtn: CLICapturedDataResponse<ResponseData>? = nil
        var err: Swift.Error? = nil
        let p = try self.captureDataResponse(arguments: arguments,
                                             environment: environment,
                                             currentDirectory: currentDirectory,
                                             standardInput: standardInput,
                                             outputOptions: outputOptions,
                                             runningEventHandlerOn: runningEventHandlerOn,
                                             eventHandler: eventHandler,
                                             withDataType: dataType) {
            (_ sender: Process,
             _ response: CLICapturedDataResponse<ResponseData>?,
             _ error: Swift.Error?) -> Void in
            
                rtn = response
                err = error
                semaphore.signal()
            
        }
                            
        guard semaphore.wait(timeout: timeout) == .success else {
          if p.isRunning {
              p.terminate()
          }
          throw CLIError.procesTimeout(p)
        }
              
        if let e = err { throw e }
        return rtn!
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns:  Returns the parsed CLICapturedStringResponse object
    func waitAndCaptureStringResponse<ARGS,
                                    EventData>(arguments: ARGS,
                                               environment: [String: String]? = nil,
                                               currentDirectory: URL? = nil,
                                               standardInput: Any? = nil,
                                               outputOptions: CLIOutputOptions = .captureAll,
                                               runningEventHandlerOn: DispatchQueue? = nil,
                                               eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                               timeout: DispatchTime = .distantFuture) throws -> CLICapturedStringResponse
        where ARGS: Sequence, ARGS.Element == String {
            
            let semaphore = DispatchSemaphore(value: 0)
            var rtn: CLICapturedStringResponse? = nil
            var err: Swift.Error? = nil
            let p = try self.captureStringResponse(arguments: arguments,
                                                   environment: environment,
                                                   currentDirectory: currentDirectory,
                                                   standardInput: standardInput,
                                                   outputOptions: outputOptions,
                                                   runningEventHandlerOn: runningEventHandlerOn,
                                                   eventHandler: eventHandler) {
                (_ sender: Process,
                 _ response: CLICapturedStringResponse?,
                 _ error: Swift.Error?) -> Void in
                
                    rtn = response
                    err = error
                    semaphore.signal()
                
            }
                                
            guard semaphore.wait(timeout: timeout) == .success else {
              if p.isRunning {
                  p.terminate()
              }
              throw CLIError.procesTimeout(p)
            }
                  
            if let e = err { throw e }
            return rtn!
    
    }
    
}

// MARK: waitAnd Methods no eventHandle parameter
public extension CLICapture {
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<ARGS,
                              CapturedData,
                              CapturedResponse>(arguments: ARGS,
                                                environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                responseParser: @escaping (_ exitStatusCode: Int32,
                                                                           _ captureOptions: CLICaptureOptions,
                                                                           _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                                timeout: DispatchTime = .distantFuture) throws -> CapturedResponse
    where ARGS: Sequence,
          ARGS.Element == String {
                  
        let semaphore = DispatchSemaphore(value: 0)
        var rtn: CapturedResponse? = nil
        var err: Swift.Error? = nil
        let p = try self.captureResponse(arguments: arguments,
                                         environment: environment,
                                         currentDirectory: currentDirectory,
                                         standardInput: standardInput,
                                         outputOptions: outputOptions,
                                         responseParser: responseParser) {
            (_ sender: Process, _ response: CapturedResponse?, _ error: Swift.Error?) -> Void in
            rtn = response
            err = error
            semaphore.signal()
            
        }
                            
        guard semaphore.wait(timeout: timeout) == .success else {
          if p.isRunning {
              p.terminate()
          }
          throw CLIError.procesTimeout(p)
        }
              
        if let e = err { throw e }
        return rtn!
              
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - responseType: The type of object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<ARGS,
                                CapturedResponse>(arguments: ARGS,
                                                  environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  withResponseType responseType: CapturedResponse.Type,
                                                  timeout: DispatchTime = .distantFuture) throws -> CapturedResponse
        where ARGS: Sequence,
              ARGS.Element == String,
              CapturedResponse: CLICapturedResponse {
                  
          let semaphore = DispatchSemaphore(value: 0)
          var rtn: CapturedResponse? = nil
          var err: Swift.Error? = nil
          let p = try self.captureResponse(arguments: arguments,
                                           environment: environment,
                                           currentDirectory: currentDirectory,
                                           standardInput: standardInput,
                                           outputOptions: outputOptions,
                                           withResponseType: responseType) {
              (_ sender: Process, _ response: CapturedResponse?, _ error: Swift.Error?) -> Void in
              rtn = response
              err = error
              semaphore.signal()
              
          }
                              
          guard semaphore.wait(timeout: timeout) == .success else {
            if p.isRunning {
                p.terminate()
            }
            throw CLIError.procesTimeout(p)
          }
                
          if let e = err { throw e }
          return rtn!
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - dataType: The type of data object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CLICapturedDataResponse object
    func waitAndCaptureDataResponse<ARGS,
                                    ResponseData>(arguments: ARGS,
                                                  environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  withDataType dataType: ResponseData.Type,
                                                  timeout: DispatchTime = .distantFuture) throws -> CLICapturedDataResponse<ResponseData>
    where ARGS: Sequence, ARGS.Element == String {
        let semaphore = DispatchSemaphore(value: 0)
        var rtn: CLICapturedDataResponse<ResponseData>? = nil
        var err: Swift.Error? = nil
        let p = try self.captureDataResponse(arguments: arguments,
                                             environment: environment,
                                             currentDirectory: currentDirectory,
                                             standardInput: standardInput,
                                             outputOptions: outputOptions,
                                             withDataType: dataType) {
            (_ sender: Process,
             _ response: CLICapturedDataResponse<ResponseData>?,
             _ error: Swift.Error?) -> Void in
            
                rtn = response
                err = error
                semaphore.signal()
            
        }
                            
        guard semaphore.wait(timeout: timeout) == .success else {
          if p.isRunning {
              p.terminate()
          }
          throw CLIError.procesTimeout(p)
        }
              
        if let e = err { throw e }
        return rtn!
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - arguments: The arguments to pass to the core process
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns:  Returns the parsed CLICapturedStringResponse object
    func waitAndCaptureStringResponse<ARGS>(arguments: ARGS,
                                            environment: [String: String]? = nil,
                                            currentDirectory: URL? = nil,
                                            standardInput: Any? = nil,
                                            outputOptions: CLIOutputOptions = .captureAll,
                                            timeout: DispatchTime = .distantFuture) throws -> CLICapturedStringResponse
        where ARGS: Sequence, ARGS.Element == String {
            
            let semaphore = DispatchSemaphore(value: 0)
            var rtn: CLICapturedStringResponse? = nil
            var err: Swift.Error? = nil
            let p = try self.captureStringResponse(arguments: arguments,
                                                   environment: environment,
                                                   currentDirectory: currentDirectory,
                                                   standardInput: standardInput,
                                                   outputOptions: outputOptions) {
                (_ sender: Process,
                 _ response: CLICapturedStringResponse?,
                 _ error: Swift.Error?) -> Void in
                
                    rtn = response
                    err = error
                    semaphore.signal()
                
            }
                                
            guard semaphore.wait(timeout: timeout) == .success else {
              if p.isRunning {
                  p.terminate()
              }
              throw CLIError.procesTimeout(p)
            }
                  
            if let e = err { throw e }
            return rtn!
    
    }
    
}


// MARK: waitAnd (No 'arguments' Parameter) Methods
public extension CLICapture {
    
    /// Execute the CLI process and capture output events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass Process events to
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns terminationStatus of the process executed
    func waitAndCapture<DATA>(environment: [String: String]? = nil,
                              currentDirectory: URL? = nil,
                              standardInput: Any? = nil,
                              outputOptions: CLIOutputOptions = .all,
                              runningEventHandlerOn: DispatchQueue? = nil,
                              eventHandler: @escaping CapturedOutputEventHandler<DATA>,
                              timeout: DispatchTime = .distantFuture) throws -> Int32 {
        
        return try self.waitAndCapture(arguments: Array<String>(),
                                       environment: environment,
                                       currentDirectory: currentDirectory,
                                       standardInput: standardInput,
                                       outputOptions: outputOptions,
                                       runningEventHandlerOn: runningEventHandlerOn,
                                       eventHandler: eventHandler,
                                       timeout: timeout)
        
        
    }
    
    /// Execute the core process
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - passthrougOptions: The passthrough options for the core process outputs
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns terminationStatus of the process executed
    func executeAndWait(environment: [String: String]? = nil,
                        currentDirectory: URL? = nil,
                        standardInput: Any? = nil,
                        passthrougOptions: CLIPassthroughOptions = .all,
                        timeout: DispatchTime = .distantFuture) throws -> Int32 {
        
        return try self.executeAndWait(arguments: Array<String>(),
                                       environment: environment,
                                       currentDirectory: currentDirectory,
                                       standardInput: standardInput,
                                       passthrougOptions: passthrougOptions,
                                       timeout: timeout)
        
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<EventData,
                                CapturedData,
                                CapturedResponse>(environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  runningEventHandlerOn: DispatchQueue? = nil,
                                                  eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                  responseParser: @escaping (_ exitStatusCode: Int32,
                                                                           _ captureOptions: CLICaptureOptions,
                                                                           _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                                  timeout: DispatchTime = .distantFuture) throws -> CapturedResponse {
                  
        return try self.waitAndCaptureResponse(arguments: Array<String>(),
                                               environment: environment,
                                               currentDirectory: currentDirectory,
                                               standardInput: standardInput,
                                               outputOptions: outputOptions,
                                               runningEventHandlerOn: runningEventHandlerOn,
                                               eventHandler: eventHandler,
                                               responseParser: responseParser,
                                               timeout: timeout)
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - responseType: The type of object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<EventData,
                              CapturedResponse>(environment: [String: String]? = nil,
                                                currentDirectory: URL? = nil,
                                                standardInput: Any? = nil,
                                                outputOptions: CLIOutputOptions = .captureAll,
                                                runningEventHandlerOn: DispatchQueue? = nil,
                                                eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                withResponseType responseType: CapturedResponse.Type,
                                                timeout: DispatchTime = .distantFuture) throws -> CapturedResponse
    where CapturedResponse: CLICapturedResponse {
        
        return try self.waitAndCaptureResponse(arguments: Array<String>(),
                                               environment: environment,
                                               currentDirectory: currentDirectory,
                                               standardInput: standardInput,
                                               outputOptions: outputOptions,
                                               runningEventHandlerOn: runningEventHandlerOn,
                                               eventHandler: eventHandler,
                                               withResponseType: responseType,
                                               timeout: timeout)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - dataType: The type of data object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CLICapturedDataResponse object
    func waitAndCaptureDataResponse<EventData,
                                    ResponseData>(environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  runningEventHandlerOn: DispatchQueue? = nil,
                                                  eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                  withDataType dataType: ResponseData.Type,
                                                  timeout: DispatchTime = .distantFuture) throws -> CLICapturedDataResponse<ResponseData> {
        
        return try self.waitAndCaptureDataResponse(arguments: Array<String>(),
                                                   environment: environment,
                                                   currentDirectory: currentDirectory,
                                                   standardInput: standardInput,
                                                   outputOptions: outputOptions,
                                                   runningEventHandlerOn: runningEventHandlerOn,
                                                   eventHandler: eventHandler,
                                                   withDataType: dataType,
                                                   timeout: timeout)
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - runningEventHandlerOn: The dispatch queue to call the event handler on
    ///   - eventHandler: The event handler to pass data events to
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CLICapturedStringResponse object
    func waitAndCaptureStringResponse<EventData>(environment: [String: String]? = nil,
                                                 currentDirectory: URL? = nil,
                                                 standardInput: Any? = nil,
                                                 outputOptions: CLIOutputOptions = .captureAll,
                                                 runningEventHandlerOn: DispatchQueue? = nil,
                                                 eventHandler: @escaping CapturedOutputEventHandler<EventData>,
                                                 timeout: DispatchTime = .distantFuture) throws -> CLICapturedStringResponse {
            
        return try self.waitAndCaptureStringResponse(arguments: Array<String>(),
                                                     environment: environment,
                                                     currentDirectory: currentDirectory,
                                                     standardInput: standardInput,
                                                     outputOptions: outputOptions,
                                                     runningEventHandlerOn: runningEventHandlerOn,
                                                     eventHandler: eventHandler,
                                                     timeout: timeout)
    
    }
    
}

// MARK: AndWait (No 'arguments', 'eventHandler' Parameters) Methods
public extension CLICapture {
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - responseParser: Closure used to parse data into CapturedResponse object
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<CapturedData,
                                CapturedResponse>(environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  responseParser: @escaping (_ exitStatusCode: Int32,
                                                                           _ captureOptions: CLICaptureOptions,
                                                                           _ capturedEvents: [CLICapturedOutputEvent<CapturedData>]) throws -> CapturedResponse,
                                                  timeout: DispatchTime = .distantFuture) throws -> CapturedResponse {
                  
        return try self.waitAndCaptureResponse(arguments: Array<String>(),
                                               environment: environment,
                                               currentDirectory: currentDirectory,
                                               standardInput: standardInput,
                                               outputOptions: outputOptions,
                                               responseParser: responseParser,
                                               timeout: timeout)
    }
    
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - responseType: The type of object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CapturedResponse object
    func waitAndCaptureResponse<CapturedResponse>(environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  withResponseType responseType: CapturedResponse.Type,
                                                  timeout: DispatchTime = .distantFuture) throws -> CapturedResponse
    where CapturedResponse: CLICapturedResponse {
        
        return try self.waitAndCaptureResponse(arguments: Array<String>(),
                                               environment: environment,
                                               currentDirectory: currentDirectory,
                                               standardInput: standardInput,
                                               outputOptions: outputOptions,
                                               withResponseType: responseType,
                                               timeout: timeout)
    }
    
    /// Execute core process and return the output as data events
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the core process outputs
    ///   - dataType: The type of data object to containd the captured response
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CLICapturedDataResponse object
    func waitAndCaptureDataResponse<ResponseData>(environment: [String: String]? = nil,
                                                  currentDirectory: URL? = nil,
                                                  standardInput: Any? = nil,
                                                  outputOptions: CLIOutputOptions = .captureAll,
                                                  withDataType dataType: ResponseData.Type,
                                                  timeout: DispatchTime = .distantFuture) throws -> CLICapturedDataResponse<ResponseData> {
        
        return try self.waitAndCaptureDataResponse(arguments: Array<String>(),
                                                   environment: environment,
                                                   currentDirectory: currentDirectory,
                                                   standardInput: standardInput,
                                                   outputOptions: outputOptions,
                                                   withDataType: dataType,
                                                   timeout: timeout)
    }
    
    /// Execute core process and return the output as string objects
    /// - Parameters:
    ///   - environment: The enviromental variables to set
    ///   - currentDirectory: The current working directory to set
    ///   - standardInput: The standard input to set the core process
    ///   - outputOptions: The capture / passthrough options for the cli process outputs
    ///   - timeout: Duration to wait for process to complete before killing process and failing out
    /// - Returns: Returns the parsed CLICapturedStringResponse object
    func waitAndCaptureStringResponse(environment: [String: String]? = nil,
                                      currentDirectory: URL? = nil,
                                      standardInput: Any? = nil,
                                      outputOptions: CLIOutputOptions = .captureAll,
                                      timeout: DispatchTime = .distantFuture) throws -> CLICapturedStringResponse {
            
        return try self.waitAndCaptureStringResponse(arguments: Array<String>(),
                                                     environment: environment,
                                                     currentDirectory: currentDirectory,
                                                     standardInput: standardInput,
                                                     outputOptions: outputOptions,
                                                     timeout: timeout)
    
    }
    
}

extension CLICapture {
    /// Print to the CLICapture output
    /// Normally this will be STD Out but can be redirected to a buffer
    /// if setup on CLICapture.init
    public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        
        let message = items.map({ return "\($0)" }).joined(separator: separator) + terminator
        guard let dta = message.data(using: .utf8, allowLossyConversion: true) else {
            return
        }
        self.writeDataToOut(DispatchData(dta))
        
    }
    
    /// Print to the CLICapture output
    /// Normally this will be STD Err but can be redirected to a buffer
    /// if setup on CLICapture.init
    public func printError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        
        let message = items.map({ return "\($0)" }).joined(separator: separator) + terminator
        guard let dta = message.data(using: .utf8, allowLossyConversion: true) else {
            return
        }
        self.writeDataToErr(DispatchData(dta))
        
    }
    
    
}
