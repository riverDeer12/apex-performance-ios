//
//  ButtonType.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 09.01.2026..
//

import Foundation

enum ButtonContentStyle: Equatable {
    case text
    case textWithIcon(systemName: String)
    case iconOnly(systemName: String)
}
