//
//  Client.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import Foundation

extension Client {
    var isOutOfCredits: Bool {
        credits ?? 0 < 1
    }
}
