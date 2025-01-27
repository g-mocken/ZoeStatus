//
//  AppDelegate.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 01.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import WatchConnectivity
import os // for os_log
//import OSLog
import Intents
import MapKit
import BackgroundTasks
import WidgetKit

let subsystem = Bundle.main.bundleIdentifier! //"com.grm.ZoeStatus"

//let customLog = Logger(subsystem: subsystem, category: "ZOE") // needs iOS 14, watchos ?
let customLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ZOE")


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
    
    var session: WCSession!
        
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message: \(message.description)")
        var reply : [String:Any] = [:]
        
        
        let userDefaults = UserDefaults.standard
        
        if
            let userName = userDefaults.string(forKey: "userName_preference"),
            let password = userDefaults.string(forKey: "password_preference")
        {
            if message["userName"] != nil {
                reply["userName"] = userName
            }
            if message["password"] != nil {
                reply["password"] = password
            }
            
            if message["api"] != nil {
                reply["api"] = userDefaults.integer(forKey: "api_preference") // cannot be nil
            }
            if message["units"] != nil {
                reply["units"] = userDefaults.integer(forKey: "units_preference") // cannot be nil
            }
            if message["kamereon"] != nil {
                reply["kamereon"] = userDefaults.string(forKey: "kamereon_preference") // cannot be nil
            }
            if message["vehicle"] != nil {
                reply["vehicle"] = userDefaults.integer(forKey: "vehicle_preference") // cannot be nil
            }

        } else {
                print ("no credentials to transfer present in iPhone") // should never happen, because user is forced to store some credentials
                
        }
        replyHandler(reply)
    
    }

    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            print("activationDidComplete without error")
            print ("current context after activation: \(session.applicationContext)")

            if  session.isPaired {
                if session.isWatchAppInstalled {
                    if session.isReachable {
                        // sent something
                    }
                } else {
                    //   NotificationCenter.default.post(name: Notification.Name("userShouldInstallApp"), object: nil)
                }
            }
            
        }  else {
            print("activationDidComplete with error: \(String(describing: error))")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // last chance to transfer anything while switching watches
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate() // re-activate session for new watch
    }
    

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("state did change")
        // The session object calls this method when the value in the isPaired, isWatchAppInstalled, isComplicationEnabled, or watchDirectoryURL properties of the WCSession object changes. Use this state to update the state of your iOS app. For example, when the complication is disabled, make a note of that fact and do not send any more data updates for the complication.
        if session.isWatchAppInstalled && session.isPaired {

            if session.isReachable {
                // sent something
            }

        }
    }
    
    var window: UIWindow?

    var shortcutItemToProcess: UIApplicationShortcutItem?

#if false
    func donateListCarsIntent() {
        let intent = INListCarsIntent()
        intent.suggestedInvocationPhrase = "List my cars"
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Error donating interaction: \(error.localizedDescription)")
            } else {
                print("Successfully donated interaction")
            }
        }
        
        let intent2 = INGetCarPowerLevelStatusIntent()
        intent2.suggestedInvocationPhrase = "Get my car's state of charge"
        let interaction2 = INInteraction(intent: intent2, response: nil)
        interaction2.donate { error in
            if let error = error {
                print("Error donating interaction2: \(error.localizedDescription)")
            } else {
                print("Successfully donated interaction2")
            }
        }

    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let intent = userActivity.interaction?.intent as? INListCarsIntent {
            // Handle the intent
            print("Handle the intent INListCarsIntent")

            return true
        }
        
        if let intent = userActivity.interaction?.intent as? INGetCarPowerLevelStatusIntent {
            // Handle the intent
            print("Handle the intent INGetCarPowerLevelStatusIntent")

            return true
        }

        return false
    }
#endif
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        print("didFinishLaunchingWithOptions")
        
        // Register the background task handler
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.grm.ZoeStatus.refresh", using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        print("BGAppRefreshTask registered")

        
        
        INPreferences.requestSiriAuthorization({ status in
            if status == .authorized {
                print("Ok - authorized")
#if false
                self.donateListCarsIntent()
#endif

            }
        })

        
        if let path = Bundle.main.path(forResource: "defaultValues", ofType: "plist") {
            let dictionary = NSDictionary(contentsOfFile: path) as! [String : Any]
            UserDefaults.standard.register(defaults: dictionary )
            print ("successfully read default values: \(dictionary)")
        } else {
            UserDefaults.standard.register(defaults: [String : Any]())
            print ("cannot read default values!")
        }
        
        // If launchOptions contains the appropriate launch options key, a Home screen quick action
        // is responsible for launching the app. Store the action for processing once the app has
        // completed initialization.
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            shortcutItemToProcess = shortcutItem
            print("Launched with shortcut \(String(describing: shortcutItemToProcess))")
            return false
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        scheduleBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        

        os_log("ZOE Custom default log mesage.", log: customLog, type: .default)
        //customLog.notice("ZOE Custom default log mesage.")
       
        os_log("ZOE Custom debug log mesage.", log: customLog, type: .debug)

        os_log("ZOE Custom info log mesage.", log: customLog, type: .info)
        //customLog.info("ZOE Custom info log mesage.")
        os_log("ZOE Custom error log mesage.", log: customLog, type: .error)
        //customLog.error("ZOE Custom error log mesage.")
        
        // Privacy only is enabled in the Console.app when running the iOS app without the debugger attached!
        //customLog.error("Private: \("top secret", privacy: .private)")
        os_log("Private: %{private}s", log: customLog, type: .error, "top secret")
        //customLog.error("Public: \("not a secret", privacy: .public)")
        os_log("Public: %{public}s", log: customLog, type: .error, "not a secret")

        /*
         // iOS 15 only, crashes when run without debugger:
         
        let logStore =  try? OSLogStore(scope: .currentProcessIdentifier)
      //  let oneHourAgo = logStore!.position(date: Date().addingTimeInterval(-3600))
        let oneMinuteAgo = logStore!.position(timeIntervalSinceEnd: -60.0)

        let match = NSPredicate(format:"(subsystem == %@) AND (category == %@)", subsystem, "ZOE")

        let allEntries = try? logStore!.getEntries(at: oneMinuteAgo, matching: match)
        for entry in allEntries! {
            print("LOG: [\(entry.date)] \(entry.composedMessage)") // does NOT presever privacy!
        }
        */
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
       
        // Only send notifications after application did become active, otherwise, they are lost in case of the first launch, because viewDidLoad has not registered, yet
        
        if WCSession.isSupported() { // not supported e.g. on iPad (static)
            session = WCSession.default
            session.delegate = self
            if session.activationState != .activated {
                session.activate()
            } else { // if activated
                if  session.isPaired {
                    if session.isWatchAppInstalled {
                        if session.isReachable {
                            // sent something
                        }
                    }
                }
            }
        }

        NotificationCenter.default.post(name: Notification.Name("applicationDidBecomeActive"), object: nil)

    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("Will be terminated") // called when manually killed from multi-app switcher by user, but not when killed via long-press on lock button followed by long press on home button, or when killed by the debugger
        
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // Alternatively, a shortcut item may be passed in through this delegate method if the app was
        // still in memory when the Home screen quick action was used. Again, store it for processing.
        shortcutItemToProcess = shortcutItem
        print("Re-launched with shortcut \(String(describing: shortcutItemToProcess))")
    }

    
    // https://developer.apple.com/documentation/UIKit/using-background-tasks-to-update-your-app
    
    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.grm.ZoeStatus.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled background task for \(request.earliestBeginDate!)")
        } catch {
            print("Failed to schedule background task: \(error)")
        }
        
        BGTaskScheduler.shared.getPendingTaskRequests(){ list in
            print("scheduled background tasks: \(list)")

        }
        
        
        // https://developer.apple.com/documentation/backgroundtasks/starting-and-terminating-tasks-during-development
        
       /* Hit breakpoint here and enter in debugger for launch:
        e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.grm.ZoeStatus.refresh"]
        */

        
        /* Hit breakpoint here and enter in debugger for termination (expiration handler):
         e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.grm.ZoeStatus.refresh"]

         */
    }

    
    func handleBackgroundRefresh(task: BGAppRefreshTask) {

        scheduleBackgroundTask()

        task.expirationHandler = {
            // Handle expiration (e.g., clean up resources).
            task.setTaskCompleted(success: true)
        }
        
        
        print("Executing scheduled background task")

        WidgetCenter.shared.reloadTimelines(ofKind: "ZoeStatus_Modern_Widget")
        
        task.setTaskCompleted(success: true)

    }
}

