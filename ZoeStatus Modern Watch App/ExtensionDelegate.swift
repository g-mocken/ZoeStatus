//
//  ExtensionDelegate.swift
//  Watch Extension
//
//  Created by Dr. Guido Mocken on 10.12.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import WatchKit
import WatchConnectivity
import ZEServices_Watchos
import ClockKit

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    let sc=ServiceConnection.shared
    var previous_last_update:UInt64?
    let refreshInterval:TimeInterval = 1 * 60
    
    
    
    fileprivate func handleLoginAsync() async -> Bool {
        
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
    
    fileprivate func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?, battery_temperature:Int?, vehicle_id:String?)->(){
        
        if (error){
            print("Could not obtain battery state.")
            ComplicationController.msg1 = "NoBatt"
        } else {
            ComplicationController.msg1 = "OkBatt"

            print("Did obtain battery state.")
            // do not use the values just retrieved here, but rely on the fact that sc.cache is updated and will be used when reloading time lines
        
//            if (previous_last_update == nil) || (previous_last_update! != last_update){
//                print("Reload required.")
            let complicationServer = CLKComplicationServer.sharedInstance()
            for complication in complicationServer.activeComplications!.filter({ $0.identifier == "com.grm.ZoeStatus.watchComplication" }) {
                    //print("reloadTimeline for complication \(complication)")
                    complicationServer.reloadTimeline(for: complication)
                    NSLog("reloadTimeline for ZOE complication \(complication.family.rawValue) after refresh")
                    
                   // let customLog = OSLog(subsystem: "com.grm.zoestatus", category: "ZOE")
                   // os_log("Log default.", log: customLog, type: .default)

                }
//            } else {
//                print("No reload required.")
//            }
            
            previous_last_update = last_update
        }
    }
    
    
    fileprivate func refreshTask(){
        // refresh
        print("Refresh triggered")
        Task {
            if ((sc.userName == nil) || (sc.password == nil)){
                
                print("No user credentials present.")
            } else {
                //ComplicationController.msg1 = "…"

                if await handleLoginAsync() {
                    //ComplicationController.msg2 = "OkLog"
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                } else {
                    //ComplicationController.msg2 = "\(sc.getError())" //"NoLog"
                }
                
                
            }
            
        } // Task
    }


    
    // MARK: - App lifecycle callbacks

    
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        print("applicationDidFinishLaunching")

        // for debugging:
//        print("clearing credentials")
//        let userDefaults = UserDefaults.standard
//        userDefaults.removeObject(forKey: "userName_preference")
//        userDefaults.removeObject(forKey: "password_preference")
//        userDefaults.synchronize()

        
//        let visibleInterfaceController = WKExtension.shared().visibleInterfaceController
//        let appDelegate = WKExtension.shared().delegate as! ExtensionDelegate



    }
    
    func applicationDidEnterBackground() {
        print("applicationDidEnterBackground")
        
        
        // do instant update of complication, if necessary
        let cache = sc.getCache()
        if cache.timestamp != nil /* cache ever updated? */ , cache.charging != nil, cache.plugged != nil, cache.charge_level != nil, cache.remaining_range != nil, cache.last_update != nil {
            
            print("Updating from cache")
            batteryState(error: false, charging: cache.charging!, plugged: cache.plugged!, charge_level: cache.charge_level!, remaining_range: cache.remaining_range!, last_update: cache.last_update!, charging_point: cache.charging_point, remaining_time: cache.remaining_time, battery_temperature: cache.battery_temperature,vehicle_id: cache.vehicleId)
        } else {
            print("Updating from network")
            refreshTask() // refresh from network, if no cache is present
        }
        
        let complicationServer = CLKComplicationServer.sharedInstance()

        
        print("Reset counter, reload all timelines...")
        ComplicationController.counter = 0 // reset Debug counter

       
   
        if complicationServer.activeComplications != nil && complicationServer.activeComplications!.filter({ $0.identifier == "com.grm.ZoeStatus.watchComplication" || $0.identifier == "com.grm.ZoeStatus.watchComplicationDebug" }).count != 0 {
          
            complicationDataProvider.schedule(first: true)
        }
        
        for complication in complicationServer.activeComplications!.filter({ $0.identifier == "com.grm.ZoeStatus.watchComplication" || $0.identifier == "com.grm.ZoeStatus.watchComplicationDebug" }) {
            complicationServer.reloadTimeline(for: complication)
            NSLog("reloadTimeline for complication \(complication.family.rawValue)")
        }
        
    }

    func applicationDidBecomeActive() {
        print("applicationDidBecomeActive")
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
       
        complicationDataProvider.backgroundURLSession.getAllTasks { tasks in
            for task in tasks {
                task.cancel()
            }
        }

        
    }

    func applicationWillResignActive() {
        print("applicationWillResignActive")

        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
   

    }

    var complicationDataProvider=ComplicationDataProvider.shared
    
    
    
    // https://developer.apple.com/documentation/SwiftUI/Scene/backgroundTask(_:action:)
    
    // https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask
  //   https://developer.apple.com/documentation/clockkit/creating-and-updating-a-complication-s-timeline
    // https://developer.apple.com/videos/play/wwdc2021/10003/ : multiple sessions (each with an id), each session has multiple tasks, but removes entire session when one task is finished and sets als tasks to complete, too?! see https://developer.apple.com/documentation/foundation/urlsession 
    // https://developer.apple.com/videos/play/wwdc2020/10049
    
    
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        NSLog("handle background tasks: \(backgroundTasks)")
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
                
                
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:

                NSLog("refresh completion handler reference")

                complicationDataProvider.refresh() { (update: Bool) -> Void in
                    
                    // completionHandler:
                    NSLog("completion handler is called, update = \(update ? "true": "false")")

                    self.complicationDataProvider.schedule(first: false)
                    
//                    if update {
                        self.updateActiveComplications()
//                    }
                    urlSessionTask.setTaskCompletedWithSnapshot(false)
                }

                
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    
    // this is called after download is complete without error (from the completionhandler)
    func updateActiveComplications() {

           let complicationServer = CLKComplicationServer.sharedInstance()

            if let activeComplications = complicationServer.activeComplications {

                for complication in activeComplications.filter({ $0.identifier == "com.grm.ZoeStatus.watchComplicationDebug" ||  $0.identifier == "com.grm.ZoeStatus.watchComplication"  } ) {
                    //print("reloadTimeline for complication \(complication)")
                    complicationServer.reloadTimeline(for: complication)
                    NSLog("reloadTimeline for debug complication \(complication.family.rawValue) before refresh")
                }

            }
        }
    

    
}
