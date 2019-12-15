//
//  InterfaceController.swift
//  Watch Extension
//
//  Created by Dr. Guido Mocken on 10.12.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import WatchKit
import Foundation
import ZEServices_Watchos
import WatchConnectivity

enum startStop {
    case start, stop
}

class InterfaceController: WKInterfaceController {
    
    var sc=ServiceConnection()

    @IBOutlet var level: WKInterfaceLabel!
    @IBOutlet var range: WKInterfaceLabel!
    @IBOutlet var date: WKInterfaceLabel!
    @IBOutlet var time: WKInterfaceLabel!
    @IBOutlet var plugged: WKInterfaceLabel!
    @IBOutlet var charger: WKInterfaceLabel!
    @IBOutlet var remaining: WKInterfaceLabel!
    @IBOutlet var charging: WKInterfaceLabel!
    
    @IBOutlet var refreshButton: WKInterfaceButton!
    
    fileprivate func displayMessage(title: String, body: String) {
        print("\(title): \(body)")
        let dismiss = WKAlertAction(title: "Dismiss", style: WKAlertActionStyle.cancel, handler: { })
        presentAlert(withTitle:title, message:body, preferredStyle: WKAlertControllerStyle.alert, actions:[dismiss])
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.

        let userDefaults = UserDefaults.standard
        ServiceConnection.userName = userDefaults.string(forKey: "userName_preference")
        ServiceConnection.password = userDefaults.string(forKey: "password_preference")

        /*
        if ((ServiceConnection.userName == nil) || (ServiceConnection.password == nil)){
            self.displayMessage(title: "Error", body: "No user credentials present, please launch iOS app to transfer them.")
            // cannot do much else in this case,
            
        } else { // credentials are present
            
            if ServiceConnection.userName == "simulation", ServiceConnection.password == "simulation"
            {
                ServiceConnection.simulation = true
            } else {
                ServiceConnection.simulation = false
            }
            
            
            if (ServiceConnection.tokenExpiry == nil){ // initial login
                sc.login(){(result:Bool)->() in
                    self.updateActivity(type:.stop)
                    if result {
                        self.refreshButtonPressed() // auto-refresh after successful login
                        print("Login to Z.E. services successful")
                    } else {
                        self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                    }
                }
            }
        }
         */
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    
    
    var activityCount: Int = 0
    func updateActivity(type:startStop){

        switch type {
        case .start:
            refreshButton.setEnabled(false)
            activityCount+=1
            break
        case .stop:
            activityCount-=1
            if activityCount<=0 {
                if activityCount<0 {
                    activityCount = 0
                }
                refreshButton.setEnabled(true)
            }
            break
        }
        print("Activity count = \(activityCount)")
    }

    
    func handleLogin(onError errorCode:@escaping()->Void, onSuccess actionCode:@escaping()->Void) {
               
        if (ServiceConnection.tokenExpiry == nil){ // never logged in successfully
        
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                if (result){
                    actionCode()
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                    errorCode()
                }
                self.updateActivity(type:.stop)
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                updateActivity(type:.start)
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
                        actionCode()
                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        print("expired token NOT renewed!")
                        errorCode()
                    }
                    self.updateActivity(type:.stop)
                }
            } else {
                print("token still valid!")
                actionCode()
            }
        }
    }
    
    
    
       func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
            
            if (error){
                displayMessage(title: "Error", body: "Could not obtain battery state.")
                
            } else {
                        
                level.setText(String(format: "🔋%3d %%", charge_level))
                range.setText(String(format: "🛣️ %3.0f km", remaining_range))
                date.setText(timestampToDateOnlyString(timestamp: last_update))
                time.setText(timestampToTimeOnlyString(timestamp: last_update))

                if plugged, charging_point != nil {
                    
                    switch (charging_point!) {
                    case "INVALID":
                        charger.setText("⛽️ " + "❌")
                        break;
                    case "SLOW":
                        charger.setText("⛽️ " + "🐌")
                        break;
                    case "FAST":
                        charger.setText("⛽️ " + "✈️")
                        break;
                    case "ACCELERATED":
                        charger.setText("⛽️ " + "🚀")
                        break;
                    default:
                        charger.setText("⛽️ " + charging_point!)
                        break;
                    }
                } else {
                    charger.setText("⛽️ …")
                }
                
                if charging, remaining_time != nil {
                    remaining.setText(String(format: "⏳ %d min.", remaining_time!))
                } else {
                    remaining.setText("⏳ …")
                }
                self.plugged.setText(plugged ? "🔌 ✅" : "🔌 ❌")
                self.charging.setText(charging ? "⚡️ ✅" : "⚡️ ❌")
                
                
                
                
            }
            updateActivity(type:.stop)

        }
    
    
    
    @IBAction func refreshButtonPressed() {
        print("Refresh!")
        if ((ServiceConnection.userName == nil) || (ServiceConnection.password == nil)){
            self.displayMessage(title: "Error", body: "No user credentials present, please launch iOS app to transfer them.")
            
            // trigger transfer from iPhone
            let context =  ["userName":"",
                            "password":"",
                            "timestamp": "\(UInt64(Date().timeIntervalSince1970))"  
            ]
            
            do {
                print ("queuing context transfer to watch: \(context)")
                try WCSession.default.updateApplicationContext(context) // it is only transmitted if it has changed!
            } catch {
                // Handle any errors
                print ("error queuing context transfer")
            }
        } else {
            handleLogin(onError: {}){
                self.updateActivity(type:.start)
                self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
            }
        }
    }

}
