//
//  ComplicationController.swift
//  Watch Extension
//
//  Created by Dr. Guido Mocken on 10.12.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import ClockKit
import ZEServices_Watchos

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    let sc=ServiceConnection.shared
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([]/*[.forward, .backward]*/) // only current
    }
    
    /*

     // func timelineEndDate(for complication: CLKComplication) async -> Date?{}
     func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
     handler(nil)
     }
     
    // func privacyBehavior(for complication: CLKComplication) async -> CLKComplicationPrivacyBehavior{}
     func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
     handler(.showOnLockScreen)
     }
     
     */
    
    // MARK: - Timeline Population
    
    fileprivate func createTemplate(for complication: CLKComplication, usingDummyValues simulation:Bool) -> CLKComplicationTemplate? {
        
        var genericTemplate:CLKComplicationTemplate?
        
        var timestamp:Date?
        
        var level: UInt8?
        var range: Float?
        var dateTime: UInt64?
        var plugged: Bool?
        var chargingPoint: String?
        var remainingTime: Int?
        var charging: Bool?
        
        if simulation {
            timestamp = Date()
            
            level = 100
            range = 234.5
            dateTime = 1550874142000
            plugged = true
            chargingPoint = "FAST"
            charging = true
            remainingTime = 123
        } else {
            
            let cache = sc.getCache()
            
            timestamp = cache.timestamp
            level = cache.charge_level
            range = cache.remaining_range
            dateTime = cache.last_update
            plugged = cache.plugged
            chargingPoint = cache.charging_point
            charging = cache.charging
            remainingTime = cache.remaining_time
            
        }
        
        let levelString = (level != nil ? String(format: "🔋%3d %%", level!) : "🔋…")
        let levelShortString = (level != nil ? String(format: "%3d", level!) : "…")
        let rangeString = (range != nil ? String(format: "🛣️ %3.0f km", range!.rounded()) : "🛣️ …")
        let /*dateString*/ _ = timestampToDateOnlyNoYearString(timestamp: dateTime)
        let /*timeString*/ _ = timestampToTimeOnlyNoSecondsString(timestamp: dateTime)
        let chargerString = chargingPointToChargerString(plugged ?? false, chargingPoint)
        
        var remainingString = remainingTimeToRemainingShortString(charging ?? false, remainingTime)
        
        let dateFormatter = DateFormatter()
        let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
        dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm:ss" //Specify your format that you want
        
        // for testing, overwrite it with cache timestamp:
        // remainingString = timestamp != nil ? dateFormatter.string(from: timestamp!) : "no time"
        
        
        
        let pluggedString = (plugged != nil ? (plugged! ? "🔌 ✅" : "🔌 ❌") : "🔌 …")
        let chargingString = (charging != nil ? (charging! ? "⚡️ ✅" : "⚡️ ❌") : "⚡️ …")
        
        // Determine the complication's family.
        switch(complication.family) {
            
            // Handle the modular small family.
        case .modularSmall:
            
            // Construct a template that displays an image and a short line of text.
            let template = CLKComplicationTemplateModularSmallRingText(textProvider: CLKSimpleTextProvider(text: levelShortString), fillFraction: Float(level ?? 0)/100, ringStyle: .closed)
           
            genericTemplate = template
            
            // Handle other supported families here.
        case .modularLarge:
            
            // Construct a template that displays an image and a short line of text.
            let template = CLKComplicationTemplateModularLargeColumns(
                row1Column1TextProvider: CLKSimpleTextProvider(text: levelString),
                row1Column2TextProvider: CLKSimpleTextProvider(text: rangeString),
                row2Column1TextProvider: CLKSimpleTextProvider(text: chargerString),
                row2Column2TextProvider: CLKSimpleTextProvider(text: chargingString),
                row3Column1TextProvider: CLKSimpleTextProvider(text: remainingString),
                row3Column2TextProvider: CLKSimpleTextProvider(text: pluggedString)
            )
            // alternate 2nd row:
            //template.row2Column1TextProvider = CLKSimpleTextProvider(text: date)
            //template.row2Column2TextProvider = CLKSimpleTextProvider(text: time)

            genericTemplate = template
            
            // Handle any non-supported families.
        default:
            genericTemplate = nil
            
        }
        
        return genericTemplate
    }
    
    // func currentTimelineEntry(for complication: CLKComplication) async -> CLKComplicationTimelineEntry? {}
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        //print("getCurrentTimelineEntry for \(complication.family.rawValue)")
        NSLog("getCurrentTimelineEntry for \(complication.family.rawValue)")
        
        if let genericTemplate = createTemplate(for:complication, usingDummyValues: false) {
            // Create the timeline entry.
            let entry = CLKComplicationTimelineEntry(date: Date(),
                                                     complicationTemplate: genericTemplate)
            // Pass the timeline entry to the handler.
            handler(entry)
        }
        else {
            handler(nil)
        }
        
    }
    
    // func timelineEntries(for complication: CLKComplication, after date: Date, limit: Int) async -> [CLKComplicationTimelineEntry]?{}
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }
    
    
    // MARK: - Placeholder Templates
    
    // localizableSampleTemplate(for complication: CLKComplication) async -> CLKComplicationTemplate?
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(createTemplate(for:complication, usingDummyValues: true))
    }
    
    
    
    // The following function plus an entry in Target -> Info -> $(PRODUCT_MODULE_NAME).ComplicationController
    // are required for a watch app without its own Info.plist file

    //func complicationDescriptors() async -> [CLKComplicationDescriptor]{}
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.grm.ZoeStatus.watchcomplication",
                displayName: "ZOE Status",
                supportedFamilies: [.modularSmall, .modularLarge]
            )
        ]
        handler(descriptors)
    }
    
}

