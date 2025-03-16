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


class InterfaceController: WKInterfaceController, WCSessionDelegate {
    
    let sc=ServiceConnection.shared

    var firstRun = true
    
    @IBOutlet var level: WKInterfaceLabel!
    @IBOutlet var range: WKInterfaceLabel!
    @IBOutlet var date: WKInterfaceLabel!
    @IBOutlet var time: WKInterfaceLabel!
    @IBOutlet var plugged: WKInterfaceLabel!
    @IBOutlet var charger: WKInterfaceLabel!
    @IBOutlet var remaining: WKInterfaceLabel!
    @IBOutlet var charging: WKInterfaceLabel!
    
    
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
            self.refreshStatus()
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
    
    
    
    // MARK: - User Interface

    
    fileprivate func displayMessage(title: String, body: String) {
        print("\(title): \(body)")
        let dismiss = WKAlertAction(title: "Dismiss", style: WKAlertActionStyle.default, handler: { })
        presentAlert(withTitle:title, message:body, preferredStyle: WKAlertControllerStyle.alert, actions:[dismiss])
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
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
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print("willActivate")
        
        var level: UInt8?
        var range: Float?
        var dateTime: UInt64?
        var plugged: Bool?
        var chargingPoint: String?
        var remainingTime: Int?
        var charging: Bool?
        
        let cache = sc.getCache()
        
        level = cache.charge_level
        range = cache.remaining_range
        dateTime = cache.last_update
        plugged = cache.plugged
        chargingPoint = cache.charging_point
        charging = cache.charging
        remainingTime = cache.remaining_time
        
        let levelString = (level != nil ? String(format: "🔋%3d %%", level!) : "🔋…")
//        let levelShortString = (level != nil ? String(format: "%3d", level!) : "…")
        let rangeString = (range != nil ? String(format: "🛣️ %3.0f km", range!.rounded()) : "🛣️ …")
        let dateString = timestampToDateOnlyString(timestamp: dateTime)
        let timeString = timestampToTimeOnlyString(timestamp: dateTime)
        let chargerString = chargingPointToChargerString(plugged ?? false, chargingPoint)
        let remainingString = remainingTimeToRemainingString(charging ?? false, remainingTime)
        let pluggedString = (plugged != nil ? (plugged! ? "🔌 ✅" : "🔌 ❌") : "🔌 …")
        let chargingString = (charging != nil ? (charging! ? "⚡️ ✅" : "⚡️ ❌") : "⚡️ …")
    
        self.level.setText(levelString)
        self.range.setText(rangeString)
        self.date.setText(dateString)
        self.time.setText(timeString)
        self.charger.setText(chargerString)
        self.remaining.setText(remainingString)
        self.plugged.setText(pluggedString)
        self.charging.setText(chargingString)


    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    override func didAppear() {
        super.didAppear()
        print("didAppear")
        if firstRun { // necessary, because this method is called whenever the main screen re-appears
            firstRun = false
            print("First start")
            refreshStatus()
            
        }
    }
    
    
    var activityCount: Int = 0
    func updateActivity(type:startStop){

        switch type {
        case .start:
            level.setAlpha(0.5)
            range.setAlpha(0.5)
            date.setAlpha(0.5)
            time.setAlpha(0.5)
            plugged.setAlpha(0.5)
            charger.setAlpha(0.5)
            remaining.setAlpha(0.5)
            charging.setAlpha(0.5)
            activityCount+=1
            break
        case .stop:
            activityCount-=1
            if activityCount<=0 {
                if activityCount<0 {
                    activityCount = 0
                }
                level.setAlpha(1.0)
                range.setAlpha(1.0)
                date.setAlpha(1.0)
                time.setAlpha(1.0)
                plugged.setAlpha(1.0)
                charger.setAlpha(1.0)
                remaining.setAlpha(1.0)
                charging.setAlpha(1.0)

            }
            break
        }
        print("Activity count = \(activityCount)")
    }

    
   
    
    func handleLoginAsync() async -> Bool {
        
        if (sc.tokenExpiry == nil){ // never logged in successfully
            
            updateActivity(type:.start)
            let r = await sc.loginAsync()
            updateActivity(type:.stop)
            
            if (r.result){
                return true
            } else {
                self.displayMessage(title: "Error", body:"Failed to login to MY.R. services."  + " (\(r.errorMessage!))")
                return false
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                updateActivity(type:.start)
                let result = await sc.renewTokenAsync()
                updateActivity(type:.stop)
                
                if result {
                    print("renewed expired token!")
                    return true
                } else {
                    //self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                    self.sc.tokenExpiry = nil // force new login next time
                    print("expired token NOT renewed!")

                    updateActivity(type:.start)
                    let r = await sc.loginAsync()
                    updateActivity(type:.stop)
                    
                    if (r.result){
                        return true
                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token and to login to MY.R. services." + " (\(r.errorMessage!))")
                        return false
                    }
                }
            } else {
                print("token still valid!")
                return true
            }
        }
    }
    
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?,battery_temperature:Int?,vehicle_id:String?)->(){
            
            if (error){
                displayMessage(title: "Error", body: "Could not obtain battery state.")
                
            } else {
                        
                level.setText(String(format: "🔋%3d %%", charge_level))
                if (remaining_range >= 0.0){
                    if (sc.units == .Metric){
                        range.setText(String(format: "🛣️ %3.0f km", remaining_range.rounded()))
                    } else {
                        range.setText(String(format: "🛣️ %3.0f mi", (remaining_range/sc.kmPerMile).rounded()))
                    }

                    
                } else {
                    range.setText(String(format: "🛣️ …"))
                }
                date.setText(timestampToDateOnlyString(timestamp: last_update))
                time.setText(timestampToTimeOnlyString(timestamp: last_update))
                charger.setText(chargingPointToChargerString(plugged, charging_point))
                remaining.setText(remainingTimeToRemainingString(charging,remaining_time))
                self.plugged.setText(plugged ? "🔌 ✅" : "🔌 ❌")
                self.charging.setText(charging ? "⚡️ ✅" : "⚡️ ❌")
            }
            updateActivity(type:.stop)
        }
    
    
    
    @IBAction func refreshStatus() {
        print("Refresh!")
        if ((sc.userName == nil) || (sc.password == nil) || (sc.units == nil) ||  (sc.api == nil) ){

            let dismiss = WKAlertAction(title: "Dismiss", style: WKAlertActionStyle.cancel, handler: {
                self.requestNewCredentialsButtonPressed()
            })
            
            presentAlert(withTitle:"Error", message:"No user credentials present.", preferredStyle: WKAlertControllerStyle.alert, actions:[dismiss])


        } else {
            /*
             handleLogin(onError: {}){
             self.updateActivity(type:.start)
             self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:battery_temperature:vehicle_id:))
            }
             */
            
            Task {
                if await handleLoginAsync() {
                    self.updateActivity(type:.start)
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                    // self.updateActivity(type:.stop)
                }
            }
        }
    }

    @IBAction func requestNewCredentialsButtonPressed() {

        let dismiss = WKAlertAction(title: "Go", style: WKAlertActionStyle.default, handler: {
            if (self.session.activationState == .activated) {
                if self.session.isReachable{
                    self.session.sendMessage(self.msg, replyHandler: self.replyHandler, errorHandler: self.errorHandler)
                } else {
                    self.displayMessage(title: "Error", body: "iPhone is not reachable.")
                }
            }
        })
        presentAlert(withTitle:"Request credentials", message:"Please make sure the iOS app is launched.", preferredStyle: WKAlertControllerStyle.alert, actions:[dismiss])

       

    }
    @IBAction func triggerAirConditioning() {
        
        print("A/C trigger!")
        if ((sc.userName == nil) || (sc.password == nil)){
            
            let dismiss = WKAlertAction(title: "Dismiss", style: WKAlertActionStyle.cancel, handler: {
                self.requestNewCredentialsButtonPressed()
            })
            
            presentAlert(withTitle:"Error", message:"No user credentials present.", preferredStyle: WKAlertControllerStyle.alert, actions:[dismiss])
            
            
        } else {
            
            /*
            handleLogin(onError: {}){
                self.updateActivity(type:.start)
                
                self.sc.precondition(command: .now, date: nil, callback: {_,_,_,_ in          self.updateActivity(type: .stop)})
            }
             */

            // async variant
            
            Task {
                if await handleLoginAsync() {
                    updateActivity(type: .start)
                    _ = await sc.preconditionAsync (command: .read, date: nil)
                    updateActivity(type:.stop)
                }
            }
        }
        
        
    }
}
