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
    var preconditionTimerCountdown = 0

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
        UserDefaults.standard.register(defaults: [String : Any]())
        
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
            self.refreshButton.isHidden=true
            activityIndicator.startAnimating()
            
            sc.login(){(result:Bool)->() in
                self.activityIndicator.stopAnimating()
                self.refreshButton.isEnabled=true
                self.refreshButton.isHidden=false
                self.preconditionButton.isEnabled = true
                
                if result {
                    self.refreshButtonPressed(self.refreshButton) // auto-refresh after successful login
                    //self.displayError(errorMessage:"Login to Z.E. services successful")
                } else {
                    self.displayError(errorMessage:"Failed to login to Z.E. services.")
                }
            }
        }
    }
    
    @objc func applicationDidBecomeActive(notification: Notification) {
        print ("notification received!")
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
    
    fileprivate func displayError(errorMessage: String) {
        let defaultAction = UIAlertAction(title: "Dismiss",
                                          style: .default) { (action) in
                                            // Respond to user selection of the action.
        }
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(defaultAction)
        
        self.present(alert, animated: true) {
            // The alert was presented
        }
    }
    
    @IBAction func refreshButtonPressed(_ sender: Any) {
        refreshButton.isEnabled=false
        refreshButton.isHidden=true
        activityIndicator.startAnimating()

        if (sc.tokenExpiry == nil){ // never logged in successfully
            sc.login(){(result:Bool)->() in
                if (result){
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                    self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))
                    
                } else {
                    self.displayError(errorMessage:"Failed to login to Z.E. services.")
                    self.refreshButton.isEnabled=true
                    self.refreshButton.isHidden=false
                    self.activityIndicator.stopAnimating()

                }
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
                        self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                        self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))

                    } else {
                        self.displayError(errorMessage:"Failed to renew expired token.")
                        print("expired token NOT renewed!")
                    }
                }
            } else {
                print("token still valid!")
                self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))

            }
        }
    }
    
    
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
        if (error){
            displayError(errorMessage: "Could not obtain battery state.")
            
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
                self.remaining.text = String(format: "⏳ %d minutes", remaining_time!)
            } else {
                self.remaining.text = "⏳ …"
            }
            self.plugged.text = plugged ? "🔌 ✅" : "🔌 ❌"
            self.charging.text = charging ? "⚡️ ✅" : "⚡️ ❌"
        }
        self.refreshButton.isEnabled=true
        self.refreshButton.isHidden=false
        self.activityIndicator.stopAnimating()
    }

    
    func acLastState(error: Bool, date:UInt64, type:String?, result:String?)->(){
        
        if (error){
            displayError(errorMessage: "Could not obtain A/C last state.")
            
        } else {
            if date != 0 , result != nil {
                self.preconditionLast.text = self.timestampToDateString(timestamp: date)
                switch (result!) {
                case "ERROR":
                    self.preconditionResult.text = "❄️🔥 ❌"
                    break
                case "SUCCESS":
                    self.preconditionResult.text = "❄️🔥 ✅"
                    break
                default:
                    self.preconditionResult.text = "…"
                }
            } else {
                self.preconditionResult.text = "…"
            }
        }
    }
        
    func preconditionState(error: Bool)->(){
        print("Precondition returns \(error)")
        if (!error){
            
            // success, start 5min timer
            preconditionTimerCountdown = 5*60
            _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                // timer periodic action:
                print("Timer=\(self.preconditionTimerCountdown)")
                self.preconditionTimerCountdown-=1
                self.preconditionTime.text = "\(self.preconditionTimerCountdown)s"
                if (self.preconditionTimerCountdown==0){
                    // timer expired after 5min countdown
                    timer.invalidate()
                    self.preconditionTime.isHidden=true
                    self.preconditionButton.isHidden=false
                    self.preconditionButton.isEnabled=true
                }
            }
            // initial setup of timer display
            preconditionTime.text = "\(preconditionTimerCountdown)s"
            preconditionTime.isHidden=false
            preconditionButton.isHidden=true
            preconditionButton.isEnabled=false
            
        } else {
            // on error,
            preconditionTime.isHidden=true
            preconditionButton.isEnabled=true
            preconditionButton.isHidden=false
        }
    }
    
    @IBAction func preconditionButtonPressed(_ sender: Any) {
        print("Precondition")
        preconditionButton.isEnabled=false;
        
        if (sc.tokenExpiry == nil){ // never logged in successfully
            sc.login(){(result:Bool)->() in
                if (result){
                    self.sc.precondition(callback: self.preconditionState)
                } else {
                    self.displayError(errorMessage:"Failed to login to Z.E. services.")
                    self.preconditionButton.isEnabled=true
                }
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
                        self.sc.precondition(callback: self.preconditionState)

                    } else {
                        self.displayError(errorMessage:"Failed to renew expired token.")
                        self.preconditionButton.isEnabled=true
                        print("expired token NOT renewed!")
                    }
                }
            } else {
                print("token still valid!")
                sc.precondition(callback: preconditionState)
            }
        }
        
        
        
        
    }
    

}

