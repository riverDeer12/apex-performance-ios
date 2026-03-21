//
//  DateFormatter.swift
//  ApexPerformance
//
//

import Foundation

extension DateFormatter {
    static let dateWithDots: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    static let dateAndTimeWithDots: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()    
    
    static let dayName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}

