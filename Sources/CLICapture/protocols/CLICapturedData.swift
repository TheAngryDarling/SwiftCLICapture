//
//  CLICapturedData.swift
//  CLIWrapper
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation
import Dispatch
import SwiftHelpfulProtocols

#if swift(>=5.0)
/// Protocol used to defin an object that can be used to store the captured data from the output streams
public protocol CLICapturedData: DataProtocol, SelfAppendable, SequenceInit
where Self.SequenceInitElement == Self.Element {
    
}


#else
/// Protocol used to defin an object that can be used to store the captured data from the output streams
public protocol CLICapturedData: Collection, SelfAppendable, SequenceInit
where Self.Element == UInt8, Self.Index == Int, Self.SequenceInitElement == Self.Element {
    
}
#endif

extension Data: CLICapturedData { }
extension DispatchData: CLICapturedData { }
