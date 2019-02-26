//
//  ViewController.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 01.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var percent:UInt8 = 0

    let baseURL =  "https://www.services.renault-ze.com/api"

    var sc=ServiceConnection()
    
    
    func timestampToDateString(timestamp: UInt64) -> String{
        var strDate = "undefined"
        
        if let unixTime = Double(exactly:timestamp/1000) {
            let date = Date(timeIntervalSince1970: unixTime)
            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "📅 dd.MM.yyyy ⏰ HH:mm:ss" //Specify your format that you want
            strDate = dateFormatter.string(from: date)
        }
        return strDate
    }
    
    fileprivate func performLogin() {

        let userDefaults = UserDefaults.standard
        let userName = userDefaults.string(forKey: "userName_preference")
        if userName != nil {
            print("User name = \(userName!)")
        }
        
        /*
         { // PERSONAL VALUES MUST BE REMOVED BEFORE GOING PUBLIC! ALSO DO NOT COMMIT TO GIT!
         let defaultUserName = "your@email.address"
         let defaultPassword = "secret password"
         
         userDefaults.setValue(defaultUserName, forKey: "userName_preference")
         userDefaults.setValue(defaultPassword, forKey: "password_preference")
         
         userDefaults.synchronize()
         }
         */
        
        sc.userName = userDefaults.string(forKey: "userName_preference")
        sc.password = userDefaults.string(forKey: "password_preference")
        
        if ((sc.userName == nil) || (sc.password == nil)){
            print ("Enter user credentials in settings app!")
            UIApplication.shared.open(URL(string : UIApplication.openSettingsURLString)!)
        } else {

            if sc.userName == "simulation", sc.password == "simulation"
            {
                sc.simulation = true
            } else {
                sc.simulation = false
            }
            
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                self.updateActivity(type:.stop)
                if result {
                    self.refreshButtonPressed(self.refreshButton) // auto-refresh after successful login
                    //self.displayError(errorMessage:"Login to Z.E. services successful")
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                }
            }
        }
    }
    
    @objc func applicationDidBecomeActive(notification: Notification) {
        print ("applicationDidBecomeActive notification received!")
        
        let userDefaults = UserDefaults.standard
        let experimentalFeatures = userDefaults.bool(forKey: "experimental_preference")
        print("experimental features = \(experimentalFeatures)")
        if (experimentalFeatures){
            chargeNowButton.isHidden = false
            requestStateButton.isHidden = false
        } else {
            chargeNowButton.isHidden = true
            requestStateButton.isHidden = true
        }

        // load settings
        if (sc.tokenExpiry == nil){
            performLogin()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("applicationDidBecomeActive"), object: nil) // remove if already present, in order to avoid double registration
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive(notification:)), name: Notification.Name("applicationDidBecomeActive"), object: nil)

    }

    /*
    override func viewDidAppear(_ animated: Bool) {
     super.viewDidAppear(animated)
    }
     */
    
    @IBOutlet var level: UILabel!
    @IBOutlet var range: UILabel!
    @IBOutlet var update: UILabel!
    @IBOutlet var charger: UILabel!
    @IBOutlet var remaining: UILabel!
    @IBOutlet var charging: UILabel!
    @IBOutlet var plugged: UILabel!
    
    @IBOutlet var refreshButton: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var preconditionButton: UIButton!
    @IBOutlet var preconditionTime: UILabel!
    @IBOutlet var preconditionLast: UILabel!
    @IBOutlet var preconditionResult: UILabel!
    
    fileprivate func displayMessage(title: String, body: String) {
        let defaultAction = UIAlertAction(title: "Dismiss",
                                          style: .default) { (action) in
                                            // Respond to user selection of the action.
        }
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(defaultAction)
        
        self.present(alert, animated: true) {
            // The alert was presented
        }
    }
  
    fileprivate func confirmButtonPress(title: String, body: String, cancelButton: String, cancelCallback:@escaping () -> Void, confirmButton: String, confirmCallback:@escaping () -> Void) {
        let cancelAction = UIAlertAction(title: cancelButton,
                                          style: .cancel) { (action) in
                                            cancelCallback()
        }
        let confirmAction = UIAlertAction(title: confirmButton,
                                         style: .default) { (action) in
                                            confirmCallback()
        }
        
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)

        
        self.present(alert, animated: true) {
            // The alert was presented
        }
    }
    
    enum startStop {
        case start, stop
    }
    
    var activityCount: Int = 0
    
    func updateActivity(type:startStop){

        switch type {
        case .start:
            refreshButton.isEnabled=false
            refreshButton.isHidden=true
            //preconditionButton.isEnabled = false
            activityIndicator.startAnimating()
            activityCount+=1
            break
        case .stop:
            activityCount-=1
            if activityCount<=0 {
                if activityCount<0 {
                    activityCount = 0
                }
                activityIndicator.stopAnimating()
                refreshButton.isEnabled=true
                refreshButton.isHidden=false
                //preconditionButton.isEnabled = true
            }
            break
        }
        print("Activity count = \(activityCount)")
    }
    func stopActivity(){
    }
    @IBAction func refreshButtonPressed(_ sender: Any) {
       
        if (sc.tokenExpiry == nil){ // never logged in successfully
        
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                if (result){
                    self.updateActivity(type:.start)
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

                    self.updateActivity(type:.start)
                    self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))
                    
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
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
                        self.updateActivity(type:.start)
                        self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                        
                        self.updateActivity(type:.start)
                        self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))

                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        print("expired token NOT renewed!")
                    }
                    self.updateActivity(type:.stop)
                }
            } else {
                print("token still valid!")
            
                updateActivity(type:.start)
                self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                updateActivity(type:.start)
                self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))

            }
        }
    }
    
    
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain battery state.")
            
        } else {
            self.level.text = String(format: "🔋%3d%%", charge_level)
            self.range.text = String(format: "🛣️ %3.0f km", remaining_range) // 📏
            
            
            //            self.update.text = String(format: "%d", last_update)
            
            self.update.text = self.timestampToDateString(timestamp: last_update)
            if plugged, charging_point != nil {
                
                switch (charging_point!) {
                case "INVALID":
                    self.charger.text = "⛽️ " + "❌"
                    break;
                case "SLOW":
                    self.charger.text = "⛽️ " + "🐌"
                    break;
                case "ACCELERATED":
                    self.charger.text = "⛽️ " + "🚀"
                    break;
                default:
                    self.charger.text = "⛽️ " + charging_point!
                    break;
                }
            } else {
                self.charger.text = "⛽️ …"
            }
            
            if charging, remaining_time != nil {
                self.remaining.text = String(format: "⏳ %d min.", remaining_time!)
            } else {
                self.remaining.text = "⏳ …"
            }
            self.plugged.text = plugged ? "🔌 ✅" : "🔌 ❌"
            self.charging.text = charging ? "⚡️ ✅" : "⚡️ ❌"
        }

        self.updateActivity(type:.stop)
    }

    
    func acLastState(error: Bool, date:UInt64, type:String?, result:String?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain A/C last state.")
            
        } else {
            if date != 0 , result != nil {
                self.preconditionLast.text = self.timestampToDateString(timestamp: date)
                switch (result!) {
                case "ERROR":
                    self.preconditionResult.text = "🌡 ❌"
                    break
                case "SUCCESS":
                    self.preconditionResult.text = "🌡 ✅"
                    break
                default:
                    self.preconditionResult.text = "🌡 …"
                }
            } else {
                self.preconditionResult.text = "🌡 …"
            }
        }
        self.updateActivity(type:.stop)
    }
        
    func preconditionState(error: Bool)->(){
        print("Precondition returns \(error)")
        if (!error){
            
            // success, start countdown timer
            let userDefaults = UserDefaults.standard
            let preconditionTimerCountdown = userDefaults.integer(forKey: "countdown_preference")
            print ("countdown in seconds = \(preconditionTimerCountdown)")
            let timerStartDate = Date.init() // current date & time
            
            _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                // timer periodic action:
                let seconds = Int(round(Date.init().timeIntervalSince(timerStartDate)))
                print("passed seconds = \(seconds)")
                
                self.preconditionTime.text = String(format: "⏲ %.02d:%02d", (preconditionTimerCountdown - seconds)/60, (preconditionTimerCountdown - seconds)%60 )

                
                if ( seconds >= preconditionTimerCountdown ){
                    // timer expired after 5min countdown
                    timer.invalidate()
                    self.preconditionTime.isHidden=true
                    self.preconditionButton.isHidden=false
                    self.preconditionButton.isEnabled=true
                }
            }
            // initial setup of timer display
            preconditionTime.text = String(format: "⏲ %.02d:%02d", preconditionTimerCountdown/60, preconditionTimerCountdown%60 )
            preconditionTime.isHidden=false
            preconditionButton.isHidden=true
            preconditionButton.isEnabled=false
            
        } else {
            // on error,
            preconditionTime.isHidden=true
            preconditionButton.isEnabled=true
            preconditionButton.isHidden=false
        }
        self.updateActivity(type: .stop)
    }
    
    @IBAction func preconditionButtonPressed(_ sender: Any) {
        print("Precondition")
        preconditionButton.isEnabled=false;
        
        confirmButtonPress(title:"Turn on air-conditioning?", body:"The car will immediately turn on A/C and leave it running for a couple of minutes. A configurable countdown will be displayed in place of the trigger button.", cancelButton: "Cancel", cancelCallback: {self.preconditionButton.isEnabled=true}, confirmButton: "Turn A/C On")
        {
            // trailing confirmCallback-closure:
            
        
            if (self.sc.tokenExpiry == nil){ // never logged in successfully
                self.updateActivity(type: .start)
                self.sc.login(){(result:Bool)->() in
                    if (result){
                        self.updateActivity(type: .start)
                        self.sc.precondition(callback: self.preconditionState)
                    } else {
                        self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                        self.preconditionButton.isEnabled=true
                    }
                    self.updateActivity(type: .stop)
                }
            } else {
                if self.sc.isTokenExpired() {
                    //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                    self.updateActivity(type:.start)
                    self.sc.renewToken(){(result:Bool)->() in
                        if result {
                            print("renewed expired token!")
                            self.updateActivity(type:.start)
                            self.sc.precondition(callback: self.preconditionState)

                        } else {
                            self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                            self.preconditionButton.isEnabled=true
                            print("expired token NOT renewed!")
                        }
                    }
                    self.updateActivity(type:.stop)
                } else {
                    print("token still valid!")
                    self.updateActivity(type: .start)
                    self.sc.precondition(callback: self.preconditionState)
                }
            }
        
        }
        
        
    }
    

    @IBOutlet var requestStateButton: UIButton!
    @IBAction func requestStateButtonPressed(_ sender: Any) {
    
        print("request state!")

        updateActivity(type:.start)
        self.sc.batteryStateUpdateRequest(callback: self.batteryStateUpdateRequest(error:))

    }
    
    
    func batteryStateUpdateRequest(error: Bool)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not request battery state.")
            
        } else {
            displayMessage(title: "Success", body: "Requested battery state.")
        }
        
        self.updateActivity(type:.stop)
    }
    
    @IBOutlet var chargeNowButton: UIButton!
    @IBAction func chargeNowButtonPressed(_ sender: Any) {
        
        print("request to charge!")
        
        updateActivity(type:.start)
        self.sc.chargeNowRequest(callback: self.chargeNowRequest(error:))

        
    }
    
    func chargeNowRequest(error: Bool)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not request to charge now.")
            
        } else {
            displayMessage(title: "Success", body: "Requested to charge now.")
        }
        
        self.updateActivity(type:.stop)
    }
}

