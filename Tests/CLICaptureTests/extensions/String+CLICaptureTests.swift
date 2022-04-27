//
//  String+CLICaptureTests.swift
//  
//
//  Created by Tyler Anger on 2022-04-27.
//

import Foundation

internal extension String {
    init?(optData: Data?, encoding: String.Encoding) {
        guard let dta = optData else {
            return nil
        }
        guard let s = String(data: dta, encoding: encoding) else {
            return nil
        }
        self = s
    }
}
