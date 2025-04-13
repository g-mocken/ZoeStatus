//
//  ComplicationController.swift
//  Watch Extension
//
//  Created by Dr. Guido Mocken on 10.12.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import ClockKit
import ZEServices_Watchos
import WatchKit

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
    static var date:Date?
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
//        let timestampString = timestamp != nil ? dateFormatter.string(from: timestamp!) : "no time"
          
        
        
        
        let pluggedString = (plugged != nil ? (plugged! ? "🔌 ✅" : "🔌 ❌") : "🔌 …")
        let chargingString = (charging != nil ? (charging! ? "⚡️ ✅" : "⚡️ ❌") : "⚡️ …")
        
        NSLog("createTemplate for complication \(complication.family.rawValue)")

        // Determine the complication's family.
        switch(complication.family) {
            
            
        case .utilitarianSmall:
            // Construct a template that displays an image and a short line of text.
            let template = CLKComplicationTemplateUtilitarianSmallRingText(textProvider: CLKSimpleTextProvider(text: levelShortString), fillFraction: Float(level ?? 0)/100, ringStyle: .closed)
            genericTemplate = template

        case .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat(textProvider: CLKSimpleTextProvider(text: levelString))
            genericTemplate = template

        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat(textProvider: CLKSimpleTextProvider(text: levelString + "   " + rangeString))
            genericTemplate = template

            
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
                    row1Column1TextProvider: CLKSimpleTextProvider(text: "C:\(timestamp?.formatted(date: .omitted, time: .shortened) ?? "…")"), // cache update
                    row1Column2TextProvider: CLKSimpleTextProvider(text: ComplicationController.msg3),
                    row2Column1TextProvider: CLKSimpleTextProvider(text: "U:\(ComplicationController.date?.formatted(date: .omitted, time: .shortened) ?? "…")"), // conmplication update
                    row2Column2TextProvider: CLKSimpleTextProvider(text: "#\(ComplicationController.counter)"),
                    row3Column1TextProvider: CLKSimpleTextProvider(text: ComplicationController.msg1),
                    row3Column2TextProvider: CLKSimpleTextProvider(text: ComplicationController.msg2)
                )
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
        NSLog("localizableSampleTemplate for \(complication)")

        return createTemplate(for:complication, usingDummyValues: true)
    }
    
    
    
    // The following function plus an entry in Target -> Info -> $(PRODUCT_MODULE_NAME).ComplicationController
    // are required for a watch app without its own Info.plist file

    func complicationDescriptors() async -> [CLKComplicationDescriptor]{
        
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.grm.ZoeStatus.watchComplication",
                displayName: "ZOE Status",
                supportedFamilies: [ .utilitarianSmall, .utilitarianSmallFlat, .utilitarianLarge, .modularSmall, .modularLarge]
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



class ComplicationDataProvider : NSObject, URLSessionDownloadDelegate {

    let sc=ServiceConnection.shared

    public static let shared = ComplicationDataProvider() // Singleton!

    var backgroundTask: URLSessionDownloadTask? // ??
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {

        print("state =  \(WKExtension.shared().applicationState)") //     case background = 2


        print("location = \(location)")
        if location.isFileURL {
            do {

                let jsonData = try Data(contentsOf: location)
                print ("json data = \(jsonData)")
                if let str = String(data: jsonData, encoding: .utf8) {
                    print("Successfully decoded data as String: \(str)")
                    ComplicationController.msg1 = str
                    ComplicationController.counter+=1
                    ComplicationController.date=Date()
                }

            } catch let error as NSError {
                print("could not read data from \(location), error = \(error)")
            }
        }
    }
    
    
    
    @MainActor fileprivate func handleLoginAsync() async -> Bool {
        
        if (sc.tokenExpiry == nil){ // never logged in successfully
            
            let r = await sc.loginAsync()
            
            if (r.result){
                return true
            } else {
                print("Failed to login to MY.R. services."  + " (\(r.errorMessage!))")
                ComplicationController.msg1 = r.errorMessage!
                return false
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                let result = await sc.renewTokenAsync()
                
                if result {
                    print("renewed expired token!")
                    return true
                } else {
                    print("Failed to renew expired token.")
                    let r = await sc.loginAsync()
                    if (r.result){
                        return true
                    }
                    else {
                        print("Failed to login to MY.R. services."  + " (\(r.errorMessage!))")
                        ComplicationController.msg1 = r.errorMessage!
                        return false
                    }
                }
            } else {
                print("token still valid!")
                return true
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        
        print("session didCompleteWithError \(error.debugDescription)") // also called when it completes without error!
        
        backgroundTask = nil // allow new schedule
        
        if let error = error as? URLError, error.code == .cancelled {
            // The request was cancelled (e.g. by you calling task.cancel())
            print("task was cancelled")
        } else {
            
            
            Task { @MainActor in
                
                if ((sc.userName == nil) || (sc.password == nil)){
                    
                    print("No user credentials present.")
                } else {
                    //ComplicationController.msg1 = "…"
                    
                    if await handleLoginAsync() {
                        //ComplicationController.msg2 = "OkLog"
                        let bs = await sc.batteryStateAsync()
                        
                        if (bs.error){
                            print("Could not obtain battery state.")
                            ComplicationController.msg1 = "NoBatt"
                        } else {
                            ComplicationController.msg1 = "OkBatt"
                            
                            print("Did obtain battery state.")
                            // do not use the values just retrieved here, but rely on the fact that sc.cache is updated and will be used when reloading time lines
                            let complicationServer = CLKComplicationServer.sharedInstance()
                            for complication in complicationServer.activeComplications!.filter({ $0.identifier == "com.grm.ZoeStatus.watchComplication" }) {
                                //print("reloadTimeline for complication \(complication)")
                                complicationServer.reloadTimeline(for: complication)
                                NSLog("reloadTimeline for ZOE complication \(complication.family.rawValue) after refresh")
                            }
                        }
                    } else {
                        //ComplicationController.msg2 = "\(sc.getError())" //"NoLog"
                    }
                }
                
                //             no completion until all request are done!
                DispatchQueue.main.async {
                    self.completionHandler?(error == nil) // if no error -> send true to indicate updateActiveComplications should be performed
                    self.completionHandler = nil
                }
                
                
                
            } // Task
            
            
        }
        
    }


    
    lazy var backgroundURLSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.grm.ZoeStatus.watchComplicationBackgroundSession")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    
    
    var completionHandler : ((_ update: Bool) -> Void)?
    
    func refresh(_ completionHandler: @escaping (_ update: Bool) -> Void) {
        print ("refresh: storing completionHandler")

        self.completionHandler = completionHandler
        
    }

    
    // THIS is the starting point (when called with first=true)
    func schedule(first: Bool) {
        // first = after 1min, others = every 15min
        
        if backgroundTask == nil {
            print ("scheduling background url session …")
            if let url = URL(string: "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_de_DE.json") // usually 403, but tht should not matter - it is just the trigger for more meaningful accesses
                
            {
                let bgTask = backgroundURLSession.downloadTask(with: url)
                
                bgTask.earliestBeginDate = Date().addingTimeInterval(first ? 60 : 15*60)
                
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone.current
                formatter.dateFormat = "HH:mm"
                let dateString = formatter.string(from: bgTask.earliestBeginDate!)
                ComplicationController.msg3 = dateString
                
                
                bgTask.countOfBytesClientExpectsToSend = 351 // measured for http (not https) request
                bgTask.countOfBytesClientExpectsToReceive = 341 // and 403 error response
                
                bgTask.resume()
                
                backgroundTask = bgTask
            }
        }
    }
}

