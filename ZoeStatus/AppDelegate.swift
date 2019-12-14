//
//  AppDelegate.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 01.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
    
    var session: WCSession!

    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("activationDidComplete")
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("state did change")
        // The session object calls this method when the value in the isPaired, isWatchAppInstalled, isComplicationEnabled, or watchDirectoryURL properties of the WCSession object changes. Use this state to update the state of your iOS app. For example, when the complication is disabled, make a note of that fact and do not send any more data updates for the complication.

    }
    
    var window: UIWindow?

    var shortcutItemToProcess: UIApplicationShortcutItem?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        print("didFinishLaunchingWithOptions")
        
        
        if WCSession.isSupported() {
            session = WCSession.default
            session.delegate = self
            session.activate()
            

        }
        
        
        
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
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
   
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

}

