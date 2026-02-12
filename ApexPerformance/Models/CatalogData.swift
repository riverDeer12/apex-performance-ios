//
//  CatalogData.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.01.2026..
//

import Foundation
import SwiftUI

struct CatalogData: Decodable {
    let id: UUID
    let name: String
    let description: String
}
