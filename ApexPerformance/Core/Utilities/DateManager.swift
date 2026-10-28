//
//  DateManager.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 17.01.2026..
//

import Foundation
import SwiftUI

struct DateManager{
    static func addTimeToDate(base: Date, timeStr: String) -> Date {
        let components = timeStr
            .split(separator: ":")
            .map { Int($0) ?? 0 }
        
        let hours = components.count > 0 ? components[0] : 0
        let minutes = components.count > 1 ? components[1] : 0
        let seconds = components.count > 2 ? components[2] : 0
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: base)
        dateComponents.hour = hours
        dateComponents.minute = minutes
        dateComponents.second = seconds
        
        return calendar.date(from: dateComponents) ?? base
    }
    
    /// A day as the API takes it, e.g. "2026-10-26": the day on the phone's
    /// calendar. Not UTC, where local midnight is still the day before.
    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
}




