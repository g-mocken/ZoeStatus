//
//  Session.swift
//  ZoeStatus Modern Watch App
//
//  Created by Guido Mocken on 28.03.25.
//  Copyright © 2025 Dr. Guido Mocken. All rights reserved.
//

import WatchKit
import WatchConnectivity
import ZEServices_Watchos

class SessionDelegate: NSObject, WCSessionDelegate, ObservableObject {
    
    
    override init() {
           super.init()
           if WCSession.isSupported() {
               
               session = WCSession.default
               session.delegate = self
               session.activate()

               // Configure interface objects here.

               let userDefaults = UserDefaults.standard
               sc.userName = userDefaults.string(forKey: "userName_preference")
               sc.password = userDefaults.string(forKey: "password_preference")
               sc.api = ServiceConnection.ApiVersion(rawValue: userDefaults.integer(forKey: "api_preference"))
               sc.units = ServiceConnection.Units(rawValue: userDefaults.integer(forKey: "units_preference"))
               sc.kamereon = userDefaults.string(forKey: "kamereon_preference")
               sc.vehicle = userDefaults.integer(forKey: "vehicle_preference")


               
           }
       }
    
    let sc=ServiceConnection.shared

    fileprivate func displayMessage(title: String, body: String) {
        print("\(title): \(body)")
    }

  
    // MARK: - Watch Connectivity

    var session: WCSession!
    let msg = ["userName":"", "password":"", "api":"", "units":"", "kamereon":"", "vehicle":""]

    fileprivate func extractCredentialsFromContext(_ context: [String:Any]) {
        print("Extracting credentials from: \(context.description)")
        
        if let userName = context["userName"], let password = context["password"], let api = context["api"], let units = context["units"], let kamereon = context["kamereon"], let vehicle = context["vehicle"]{
            sc.userName =  userName as? String
            sc.password = password as? String
            sc.api = ServiceConnection.ApiVersion(rawValue: (api as? Int) ?? 0)
            sc.units = ServiceConnection.Units(rawValue: (units as? Int) ?? 0)
            sc.kamereon = kamereon as? String
            sc.vehicle = vehicle as? Int
            // store preferences
            let userDefaults = UserDefaults.standard
            userDefaults.set(sc.userName, forKey: "userName_preference")
            userDefaults.set(sc.password, forKey: "password_preference")
            userDefaults.set(sc.api?.rawValue, forKey: "api_preference")
            userDefaults.set(sc.units?.rawValue, forKey: "units_preference")
            userDefaults.set(sc.kamereon, forKey: "kamereon_preference")
            userDefaults.set(sc.vehicle, forKey: "vehicle_preference")

            userDefaults.synchronize()
        }
    }
    
    func replyHandler(reply: [String:Any])->Void{
        print("Received reply: \(reply)")
        extractCredentialsFromContext(reply)
        DispatchQueue.main.async{
            self.displayMessage(title: "Success", body: "Credentials received and stored.")
            self.sc.tokenExpiry = nil // require new login
            // TODO self.refreshStatus()
        }
    }
    
    func errorHandler(error: Error) -> Void{
        print("Received error: \(error)")
        displayMessage(title: "Error", body: "There was a problem while receiving the credentials.")
    }
    
    func requestCredentials(_ session: WCSession){
        if (session.activationState == .activated) {
            if session.isReachable{
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
    
    
}
