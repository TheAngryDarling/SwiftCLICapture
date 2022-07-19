import XCTest
import Dispatch
@testable import CLICapture

final class CLICaptureTests: XCTestCase {
    
    
    func testCLICaptureOptions() {
        
        let passthroughNone = CLIPassthroughOptions.none
        let passthroughOut = CLIPassthroughOptions.out
        let passthroughErr = CLIPassthroughOptions.err
        let passthroughAll = CLIPassthroughOptions.all
        
        let captureNone = CLICaptureOptions.none
        let captureOut = CLICaptureOptions.out
        let captureErr = CLICaptureOptions.err
        let captureAll = CLICaptureOptions.all
        
        let outputNone = CLIOutputOptions.none
        let outputAll = CLIOutputOptions.all
        
        let outputCaptureOut = CLIOutputOptions.captureOut
        let outputCaptureErr = CLIOutputOptions.captureErr
        let outputCaptureAll = CLIOutputOptions.captureAll
        
        let outputPassthroughOut = CLIOutputOptions.passthroughOut
        let outputPassthroughErr = CLIOutputOptions.passthroughErr
        let outputPassthroughAll = CLIOutputOptions.passthroughAll
        
        let outputOut: CLIOutputOptions = [CLIOutputOptions.passthroughOut, CLIOutputOptions.captureOut]
        let outputErr: CLIOutputOptions = [CLIOutputOptions.passthroughErr, CLIOutputOptions.captureErr]
        
        XCTAssertEqual(CLIPassthroughOptions.mask, 0x03)
        XCTAssertEqual(passthroughNone.rawValue, 0)
        XCTAssertEqual(passthroughOut.rawValue, 1)
        XCTAssertEqual(passthroughOut.rawValue, CLIPassthroughOptions.smallestSingleValue)
        XCTAssertEqual(passthroughErr.rawValue, CLIPassthroughOptions.highestSingleValue)
        XCTAssertEqual(passthroughErr.rawValue, 2)
        XCTAssertTrue(passthroughAll.contains(.out))
        XCTAssertTrue(passthroughAll.contains(.err))
        XCTAssertEqual(CLIPassthroughOptions(rawValue: 0xFF).rawValue, CLIPassthroughOptions.all.rawValue)
        
        XCTAssertEqual(CLICaptureOptions.mask, 0x0C)
        XCTAssertEqual(captureNone.rawValue, 0)
        XCTAssertEqual(captureOut.rawValue, CLICaptureOptions.smallestSingleValue)
        XCTAssertEqual(captureOut.rawValue, 4)
        XCTAssertEqual(captureErr.rawValue, CLICaptureOptions.highestSingleValue)
        XCTAssertEqual(captureErr.rawValue, 8)
        XCTAssertTrue(captureAll.contains(.out))
        XCTAssertTrue(captureAll.contains(.err))
        XCTAssertEqual(CLICaptureOptions(rawValue: 0xFF).rawValue, CLICaptureOptions.all.rawValue)
        
        XCTAssertEqual(outputNone.rawValue, 0)
        XCTAssertEqual(outputAll.rawValue,
                       (CLICaptureOptions.all + CLIPassthroughOptions.all).rawValue)
        
        XCTAssertEqual(outputPassthroughOut.passthrough.rawValue, CLIPassthroughOptions.out.rawValue)
        XCTAssertEqual(outputPassthroughErr.passthrough.rawValue, CLIPassthroughOptions.err.rawValue)
        XCTAssertEqual(outputPassthroughAll.passthrough.rawValue, CLIPassthroughOptions.all.rawValue)
        
        XCTAssertEqual(outputCaptureOut.capture.rawValue, CLICaptureOptions.out.rawValue)
        XCTAssertEqual(outputCaptureErr.capture.rawValue, CLICaptureOptions.err.rawValue)
        XCTAssertEqual(outputCaptureAll.capture.rawValue, CLICaptureOptions.all.rawValue)
        
        XCTAssertEqual(outputErr.capture.rawValue, CLICaptureOptions.err.rawValue)
        XCTAssertEqual(outputErr.passthrough.rawValue, CLIPassthroughOptions.err.rawValue)
        
        XCTAssertEqual(outputOut.capture.rawValue, CLICaptureOptions.out.rawValue)
        XCTAssertEqual(outputOut.passthrough.rawValue, CLIPassthroughOptions.out.rawValue)
        
        
        
    }
    
    func _testOut<Q>(_ q: Q) where Q: Lockable {
        let cliCapture = CLICapture(outputLock: q,
                                    executable: URL(fileURLWithPath: "/usr/bin/swift"))
        
        let stdOutBuffer = CLICapture.STDBuffer()
        let stdErrBuffer = CLICapture.STDBuffer()
        
        
        cliCapture.stdOutBuffer = stdOutBuffer
        cliCapture.stdErrBuffer = stdErrBuffer
        
        var hasOutputWritten: Bool = false
        func outputWritten(_ p: Process, _ std: CLICapture.STDOutputStream) {
            hasOutputWritten = true
        }
        do {
            
            var respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["--version"],
                                                                     outputOptions: .captureOut,
                                                                     withDataType: Data.self,
                                                                     processWroteToItsSTDOutput: outputWritten)
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            var resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["--version"],
                                                                 outputOptions: .captureOut,
                                                                   processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            guard XCTAssertsEqual(resp.exitStatusCode, 0,
                                  "Executing Swift Returned error code") else {
                return
            }
            
            //print("Getting stdOut")
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Out should have been empty but found '\(str)'")
            }
            
            //print("Getting stdErr")
            if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Err should have been empty but found '\(str)'")
            }
            
            XCTAssertTrue(resp.out?.contains("Swift version") ?? false,
                          "Captured STD Out does not contain 'Swift version' in '\(resp.out ?? "")'")
            let coreOut = String(optData: respCore.out, encoding: .utf8)
            XCTAssertTrue(coreOut?.contains("Swift version") ?? false,
                          "Captured STD Out does not contain 'Swift version' in '\(coreOut ?? "")'")
            
            XCTAssertTrue(resp.err == nil, "Captured STD Err is not nil")
            XCTAssertTrue(respCore.err == nil, "Captured STD Err is not nil")
            
            respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["--version"],
                                                                     outputOptions: .passthroughOut,
                                                                     withDataType: Data.self,
                                                                 processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["--version"],
                                                               outputOptions: .passthroughOut,
                                                               processWroteToItsSTDOutput: outputWritten)
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertEqual(resp.exitStatusCode, 0,
                           "Executing Swift Returned error code")
            XCTAssertTrue(resp.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(respCore.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(resp.err == nil, "Captured STD Err is not nil")
            XCTAssertTrue(respCore.err == nil, "Captured STD Err is not nil")
            
            //print("Getting stdOut")
            guard let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) else {
                XCTFail("Unable to create string from STDOUT")
                return
            }
            
            XCTAssertTrue(str.contains("Swift version"),
                          "Captured STD Out does not contain 'Swift version' in '\(resp.out ?? "")'")
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testOut() {
        _testOut(NSLock())
        _testOut(DispatchQueue(label: "CLICapture.Output"))
        _testOut(OperationQueue())
    }
    
    func _testErr<Q>(_ q: Q) where Q: Lockable {
        let cliCapture = CLICapture(outputLock: q,
                                    executable: URL(fileURLWithPath: "/usr/bin/swift"))
        
        let stdOutBuffer = CLICapture.STDBuffer()
        let stdErrBuffer = CLICapture.STDBuffer()
        
        
        cliCapture.stdOutBuffer = stdOutBuffer
        cliCapture.stdErrBuffer = stdErrBuffer
        
        var hasOutputWritten: Bool = false
        func outputWritten(_ p: Process, _ std: CLICapture.STDOutputStream) {
            hasOutputWritten = true
        }
        
        do {
            
            let respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["-blah"],
                                                                     outputOptions: .captureErr,
                                                                     withDataType: Data.self,
                                                                     processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            var resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["-blah"],
                                                                   outputOptions: .captureErr,
                                                                   processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertNotEqual(resp.exitStatusCode, 0,
                              "Executing Swift did NOT return error code")
            XCTAssertTrue(resp.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(respCore.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(resp.err != nil, "Captured STD Err should not be nil")
            XCTAssertTrue(respCore.err != nil, "Captured STD Err should not be nil")
            
            //print("Getting stdOut")
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Out should have been empty but found '\(str)'")
            }
            
            //print("Getting stdErr")
            if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Out should have been empty but found '\(str)'")
            }
            
            resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["-blah"],
                                                                   outputOptions: .passthroughErr,
                                                               processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertNotEqual(resp.exitStatusCode, 0,
                              "Executing Swift did NOT return error code")
            XCTAssertTrue(resp.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(resp.err == nil, "Captured STD Out is not nil")
            
            //print("Getting stdOut")
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Out should have been empty but found '\(str)'")
            }
            
            //print("Getting stdErr")
            if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(!str.isEmpty,
                              "STD Out should not be empty")
            }
            
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testErr() {
        _testErr(NSLock())
        _testErr(DispatchQueue(label: "CLICapture.Output"))
        _testErr(OperationQueue())
    }
    
    func _testNone<Q>(_ q: Q) where Q: Lockable {
        let cliCapture = CLICapture(outputLock: q,
                                    executable: URL(fileURLWithPath: "/usr/bin/swift"))
        
        let stdOutBuffer = CLICapture.STDBuffer()
        let stdErrBuffer = CLICapture.STDBuffer()
        
        cliCapture.stdOutBuffer = stdOutBuffer
        cliCapture.stdErrBuffer = stdErrBuffer
        
        var hasOutputWritten: Bool = false
        func outputWritten(_ p: Process, _ std: CLICapture.STDOutputStream) {
            hasOutputWritten = true
        }
        
        
        do {
            
            var respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["--version"],
                                                                     outputOptions: .none,
                                                                     withDataType: Data.self,
                                                                     processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            var resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["-version"],
                                                                   outputOptions: .none,
                                                                   processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            guard XCTAssertsEqual(resp.exitStatusCode, 0,
                                  "Executing Swift Returned error code") else {
                return
            }
            
            //print("Getting stdOut")
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Out should have been empty but found '\(str)'")
            }
            
            //print("Getting stdErr")
            if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Err should have been empty but found '\(str)'")
            }
            
            XCTAssertTrue(resp.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(respCore.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(resp.err == nil, "Captured STD Out is not nil")
            XCTAssertTrue(respCore.err == nil, "Captured STD Out is not nil")
            
            
            respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["-blah"],
                                                                     outputOptions: .none,
                                                                     withDataType: Data.self,
                                                                 processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["-blah"],
                                                                   outputOptions: .none,
                                                               processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertNotEqual(resp.exitStatusCode, 0,
                              "Executing Swift did NOT return error code")
            //print("Getting stdOut")
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Out should have been empty but found '\(str)'")
            }
            
            //print("Getting stdErr")
            if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Err should have been empty but found '\(str)'")
            }
            
            XCTAssertTrue(resp.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(respCore.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(resp.err == nil, "Captured STD Out is not nil")
            XCTAssertTrue(respCore.err == nil, "Captured STD Out is not nil")
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testNone() {
        _testNone(NSLock())
        _testNone(DispatchQueue(label: "CLICapture.Output"))
        _testNone(OperationQueue())
    }
    
    func _testAll<Q>(_ q: Q) where Q: Lockable {
        let cliCapture = CLICapture(outputLock: q,
                                    executable: URL(fileURLWithPath: "/usr/bin/swift"))
        
        let stdOutBuffer = CLICapture.STDBuffer()
        let stdErrBuffer = CLICapture.STDBuffer()
        
        
        cliCapture.stdOutBuffer = stdOutBuffer
        cliCapture.stdErrBuffer = stdErrBuffer
        
        var hasOutputWritten: Bool = false
        func outputWritten(_ p: Process, _ std: CLICapture.STDOutputStream) {
            hasOutputWritten = true
        }
        
        do {
            
            var respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["--version"],
                                                                     outputOptions: .all,
                                                                     withDataType: Data.self,
                                                                     processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            var resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["--version"],
                                                                outputOptions: .all,
                                                                   processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            guard XCTAssertsEqual(resp.exitStatusCode, 0,
                                  "Executing Swift Returned error code") else {
                return
            }
            
            //print("Getting stdOut")
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.contains("Swift version"),
                              "Captured STD Out does not contain 'Swift version' in '\(str)'")
            }
            
            //print("Getting stdErr")
            /*if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty,
                              "STD Err should have been empty but found '\(str)'")
            }*/
            
            XCTAssertTrue(resp.out?.contains("Swift version") ?? false,
                          "Captured STD Out does not contain 'Swift version' in '\(resp.out ?? "")'")
            XCTAssertTrue(String(optData: respCore.out,
                                 encoding: .utf8)?.contains("Swift version") ?? false,
                          "Captured STD Out does not contain 'Swift version' in '\(String(optData: respCore.out, encoding: .utf8) ?? "")'")
            //XCTAssertTrue(resp.err == nil || resp.err!.isEmpty, "Captured STD Err is not nil")
            
            respCore = try cliCapture.waitAndCaptureDataResponse(arguments: ["--blah",
                                                                             "-version"],
                                                                     outputOptions: .all,
                                                                     withDataType: Data.self,
                                                                 processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["--blah",
                                                                           "-version"],
                                                               outputOptions: .all,
                                                               processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertNotEqual(resp.exitStatusCode, 0,
                              "Executing Swift did NOT return error code")
            //XCTAssertTrue(resp.out == nil, "Captured STD Out is not nil")
            XCTAssertTrue(resp.err != nil, "Captured STD Err is nil")
            XCTAssertTrue(respCore.err != nil, "Captured STD Err is nil")
            
            //print("Getting stdOut")
            /*guard let stdOut = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) else {
                XCTFail("Unable to create string from STDOUT")
                return
            }*/
            
            guard let stdErr = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) else {
                XCTFail("Unable to create string from STDOUT")
                return
            }
            
            XCTAssertTrue(!stdErr.isEmpty, "Captured STD Err is empty")
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testAll() {
        _testAll(NSLock())
        _testAll(DispatchQueue(label: "CLICapture.Output"))
        _testAll(OperationQueue())
    }
    
    func _testExecute<Q>(_ q: Q) where Q: Lockable {
        let cliCapture = CLICapture(outputLock: q,
                                    executable: URL(fileURLWithPath: "/usr/bin/swift"))
        
        let stdOutBuffer = CLICapture.STDBuffer()
        let stdErrBuffer = CLICapture.STDBuffer()
        
        
        cliCapture.stdOutBuffer = stdOutBuffer
        cliCapture.stdErrBuffer = stdErrBuffer
        
        var hasOutputWritten: Bool = false
        func outputWritten(_ p: Process, _ std: CLICapture.STDOutputStream) {
            hasOutputWritten = true
        }
        
        do {
            let ret = try cliCapture.executeAndWait(arguments: ["-version"],
                                              passthrougOptions: .none,
                                                    processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertEqual(ret, 0,
                           "Executing Swift Returned error code")
            
            if let str = String(data: stdOutBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.isEmpty, "Expected STD Out to be empty.  Found '\(str)'")
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let ret = try cliCapture.executeAndWait(arguments: ["-blah"],
                                              passthrougOptions: .all,
                                                    processWroteToItsSTDOutput: outputWritten)
            
            XCTAssertEqual(hasOutputWritten, true)
            hasOutputWritten = false
            
            XCTAssertNotEqual(ret, 0,
                              "Executing Swift did NOT return error code")
            
            if let str = String(data: stdErrBuffer.readBuffer(),
                                encoding: .utf8) {
                XCTAssertTrue(str.contains("unknown argument: '-blah"),
                              "Expected STD Err to contain 'unknown argument: '-blah''. '\(str)'")
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testExecute() {
        _testExecute(NSLock())
        _testExecute(DispatchQueue(label: "CLICapture.Output"))
        _testExecute(OperationQueue())
    }
    
    static var allTests = [
        ("testCLICaptureOptions", testCLICaptureOptions),
        ("testOut", testOut),
        ("testErr", testErr),
        ("testAll", testAll),
        ("testNone", testNone),
        ("testExecute", testExecute)
    ]
}
