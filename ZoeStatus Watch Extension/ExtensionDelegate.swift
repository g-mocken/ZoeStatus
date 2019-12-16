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

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
    
    var session: WCSession!
    
    fileprivate func extractCredentialsFromContext(_ context: [String:Any]) {
        print("Trying context: \(context.description)")
        
        if let userName = context["userName"], let password = context["password"] {
            ServiceConnection.userName =  userName as? String
            ServiceConnection.password = password as? String
           
            if ServiceConnection.userName == "simulation", ServiceConnection.password == "simulation"
            {
                ServiceConnection.simulation = true
            } else {
                ServiceConnection.simulation = false
            }
            
            
            // store preferences
            let userDefaults = UserDefaults.standard
            userDefaults.set(ServiceConnection.userName, forKey: "userName_preference")
            userDefaults.set(ServiceConnection.password, forKey: "password_preference")
            userDefaults.synchronize()
        }
    }
    
    func replyHandler(reply: [String:Any])->Void{
        print("Received reply: \(reply)")
        extractCredentialsFromContext(reply)
    }
    
    func errorHandler(error: Error) -> Void{
        print("Received error: \(error)")
    }
    
    func requestCredentials(_ session: WCSession){
        if (session.activationState == .activated) {
            if session.isReachable{
                let msg = ["userName":"", "password":""]
                session.sendMessage(msg, replyHandler: replyHandler, errorHandler: errorHandler)
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("activationDidComplete")
        if error == nil {
            //requestCredentials(session)
        }
    }
    
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        // for debugging:
//        print("clearing credentials")
//        let userDefaults = UserDefaults.standard
//        userDefaults.removeObject(forKey: "userName_preference")
//        userDefaults.removeObject(forKey: "password_preference")
//        userDefaults.synchronize()

        session = WCSession.default
        session.delegate = self
        session.activate()
        
//        let visibleInterfaceController = WKExtension.shared().visibleInterfaceController
        
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
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
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

}
