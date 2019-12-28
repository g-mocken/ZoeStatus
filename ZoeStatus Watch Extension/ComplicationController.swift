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
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
   
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    */
    
    // MARK: - Timeline Population
    
    fileprivate func createTemplate(for complication: CLKComplication, usingDummyValues simulation:Bool) -> CLKComplicationTemplate? {
        
        var genericTemplate:CLKComplicationTemplate?
        
        
        var level: UInt8?
        var range: Float?
        var dateTime: UInt64?
        var plugged: Bool?
        var chargingPoint: String?
        var remainingTime: Int?
        var charging: Bool?
        
        if simulation {
            level = 100
            range = 234.5
            dateTime = 1550874142000
            plugged = true
            chargingPoint = "FAST"
            charging = true
            remainingTime = 123
        } else {
            
            let cache = sc.getCache()
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
  //      let dateString = timestampToDateOnlyNoYearString(timestamp: dateTime)
  //      let timeString = timestampToTimeOnlyNoSecondsString(timestamp: dateTime)
        let chargerString = chargingPointToChargerString(plugged ?? false, chargingPoint)
        let remainingString = remainingTimeToRemainingShortString(charging ?? false, remainingTime)
        let pluggedString = (plugged != nil ? (plugged! ? "🔌 ✅" : "🔌 ❌") : "🔌 …")
        let chargingString = (charging != nil ? (charging! ? "⚡️ ✅" : "⚡️ ❌") : "⚡️ …")

        // Determine the complication's family.
        switch(complication.family) {
            
        // Handle the modular small family.
        case .modularSmall:
            
            // Construct a template that displays an image and a short line of text.
            let template = CLKComplicationTemplateModularSmallRingText()
            // Set the data providers.
            template.fillFraction = Float(level ?? 0)/100
            template.ringStyle = .closed
            template.textProvider = CLKSimpleTextProvider(text: levelShortString)
            // let myIcon = UIImage(systemName: "exclamationmark.triangle") //(named: "complication.png")
            // template.line1ImageProvider = CLKImageProvider(onePieceImage: myIcon!)
            // template.line2TextProvider = CLKSimpleTextProvider(text: "blabla")
            //              template.highlightLine2 = true
            
            genericTemplate = template
            
        // Handle other supported families here.
        case .modularLarge:
            
            // Construct a template that displays an image and a short line of text.
            let template = CLKComplicationTemplateModularLargeColumns()
            // Set the data providers.
            template.row1Column1TextProvider = CLKSimpleTextProvider(text: levelString)
            template.row1Column2TextProvider = CLKSimpleTextProvider(text: rangeString)
            //template.row2Column1TextProvider = CLKSimpleTextProvider(text: date)
            //template.row2Column2TextProvider = CLKSimpleTextProvider(text: time)
            template.row2Column1TextProvider = CLKSimpleTextProvider(text: chargerString)
            template.row2Column2TextProvider = CLKSimpleTextProvider(text: chargingString)
            template.row3Column1TextProvider = CLKSimpleTextProvider(text: remainingString)
            template.row3Column2TextProvider = CLKSimpleTextProvider(text: pluggedString)
            
            genericTemplate = template
            
            
            
        // Handle any non-supported families.
        default:
            genericTemplate = nil
            
        }
        
        return genericTemplate
    }
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        print("getCurrentTimelineEntry for \(complication.family.rawValue)")
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
    /*
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }
    */

    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(createTemplate(for:complication, usingDummyValues: true))
    }
        
}
    

