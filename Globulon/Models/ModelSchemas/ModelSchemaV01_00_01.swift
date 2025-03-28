//
//  ModelSchemaV1.swift
//  Globulon
//
//  Created by David Holeman on 02/25/25.
//  Copyright © 2025 OpEx Networks, LLC. All rights reserved.
//

import Foundation
import SwiftData
import CoreLocation

enum ModelSchemaV01_00_01: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        return Schema.Version(1, 0, 1)
    }
    
    static var models: [any PersistentModel.Type] {
        return [
            HelpArticle.self,
            HelpSection.self,
            GPSData.self,
        ]
    }
    
    /// Sections
    ///
    @Model
    class HelpSection {
        
        @Attribute(.unique) var id: String
        var section: String
        var rank: String
        
        var toArticles: [HelpArticle]?
        
        init(id:String, section: String, rank: String) {
            self.id = id
            self.section = section
            self.rank = rank
        }
    }

    /// Articles
    ///
    @Model
    class HelpArticle {
        var id: String
        var title: String
        var summary: String
        var search: String
        var section: String
        var body: String
        
        @Relationship(inverse: \HelpSection.toArticles) var toSection: HelpSection?

        init(id: String, title: String, summary: String, search: String, section: String, body: String) {
            self.id = id
            self.title = title
            self.summary = summary
            self.search = search
            self.section = section
            self.body = body
        }
    }
    
    /// GPS Journal
    /// This is the raw GPS location data collected by the Location Manager
    ///
    @Model
    class GPSData {

        @Attribute(.unique) var timestamp: Date
        var latitude: Double
        var longitude: Double
        var speed: Double
        var processed: Bool
        @Attribute(originalName: "code") var codes: String  //Rename the field
        var note: String

        init(timestamp: Date, latitude: Double, longitude: Double, speed: Double, processed: Bool, code: String, note: String) {
            self.timestamp = timestamp
            self.latitude = latitude
            self.longitude = longitude
            self.speed = speed
            self.processed = processed
            self.codes = code  // The schema now uses has the new name "codes" in the model but the old code referenceing "code" is still out there
            self.note = note
        }
    }
    
}

