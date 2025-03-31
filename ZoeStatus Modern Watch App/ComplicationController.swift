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
    
    
    func timelineEndDate(for complication: CLKComplication) async -> Date?{
        return nil // The end date for your data. If you specify nil, ClockKit doesn’t ask for any more future data.
    }
    
    func privacyBehavior(for complication: CLKComplication) async -> CLKComplicationPrivacyBehavior{
        return .showOnLockScreen
    }
    
     
    
    // MARK: - Timeline Population
    
    static var counter:UInt = 0
    static var msg1 = "…"
    static var msg2 = "…"
    static var msg3 = "…"

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
        
        let remainingString = remainingTimeToRemainingShortString(charging ?? false, remainingTime)
      
        let dateFormatter = DateFormatter()
        let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
        dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm:ss" //Specify your format that you want
    
        // for testing, replace it with cache timestamp:
        // let remainingString = timestamp != nil ? dateFormatter.string(from: timestamp!) : "no time"
        let timestampString = timestamp != nil ? dateFormatter.string(from: timestamp!) : "no time"
          
        
        
        
        let pluggedString = (plugged != nil ? (plugged! ? "🔌 ✅" : "🔌 ❌") : "🔌 …")
        let chargingString = (charging != nil ? (charging! ? "⚡️ ✅" : "⚡️ ❌") : "⚡️ …")
        
        NSLog("createTemplate for complication \(complication.family.rawValue)")

        // Determine the complication's family.
        switch(complication.family) {
            
            // Handle the modular small family.
        case .modularSmall:
            
            // Construct a template that displays an image and a short line of text.
            let template = CLKComplicationTemplateModularSmallRingText(textProvider: CLKSimpleTextProvider(text: levelShortString), fillFraction: Float(level ?? 0)/100, ringStyle: .closed)
           
            genericTemplate = template
            
            // Handle other supported families here.
        case .modularLarge:
            if (complication.identifier == "com.grm.ZoeStatus.watchComplicationDebug"){
                // Construct a template that displays an image and a short line of text.
                let template = CLKComplicationTemplateModularLargeColumns(
                    row1Column1TextProvider: CLKSimpleTextProvider(text: "C:\(timestampString)"), // cache update
                    row1Column2TextProvider: CLKSimpleTextProvider(text: ComplicationController.msg3),
                    row2Column1TextProvider: CLKSimpleTextProvider(text: "U:\(dateFormatter.string(from: Date() ))"), // conmplication update
                    row2Column2TextProvider: CLKSimpleTextProvider(text: "#\(ComplicationController.counter)"),
                    row3Column1TextProvider: CLKSimpleTextProvider(text: ComplicationController.msg1),
                    row3Column2TextProvider: CLKSimpleTextProvider(text: ComplicationController.msg2)
                )
                ComplicationController.counter+=1
                genericTemplate = template
            } else {
                
                
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
            }
            // Handle any non-supported families.
        default:
            genericTemplate = nil
            
        }
        
        return genericTemplate
    }
    
    func currentTimelineEntry(for complication: CLKComplication) async -> CLKComplicationTimelineEntry? {
        // return the current timeline entry
        //print("getCurrentTimelineEntry for \(complication.family.rawValue)")
        NSLog("getCurrentTimelineEntry for \(complication.family.rawValue)")
        
        if let genericTemplate = createTemplate(for:complication, usingDummyValues: false) {
            // Create the timeline entry.
            let entry = CLKComplicationTimelineEntry(date: Date(),
                                                     complicationTemplate: genericTemplate)
            // return the timeline entry
            return entry
        }
        else {
            return nil
        }
        
    }
    
    func timelineEntries(for complication: CLKComplication, after date: Date, limit: Int) async -> [CLKComplicationTimelineEntry]?{
        // return the timeline entries after to the given date
        return nil
    }
    
    
    // MARK: - Placeholder Templates
    
    func localizableSampleTemplate(for complication: CLKComplication) async -> CLKComplicationTemplate? {
        return createTemplate(for:complication, usingDummyValues: true)
    }
    
    
    
    // The following function plus an entry in Target -> Info -> $(PRODUCT_MODULE_NAME).ComplicationController
    // are required for a watch app without its own Info.plist file

    func complicationDescriptors() async -> [CLKComplicationDescriptor]{
        
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.grm.ZoeStatus.watchComplication",
                displayName: "ZOE Status",
                supportedFamilies: [.modularSmall, .modularLarge]
            ),
            CLKComplicationDescriptor(
                identifier: "com.grm.ZoeStatus.watchComplicationDebug",
                displayName: "ZOE Debug",
                supportedFamilies: [.modularLarge]
            )
        ]
        return descriptors
    }
    
}

