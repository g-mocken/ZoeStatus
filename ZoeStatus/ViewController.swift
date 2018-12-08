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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        UserDefaults.standard.register(defaults: [String : Any]())

        
        let userDefaults = UserDefaults.standard
        let userName = userDefaults.string(forKey: "userName_preference")
        if userName != nil {
            print("User name = \(userName!)")
        }
        
        if false { // PERSONAL VALUES MUST BE REMOVED BEFORE GOING PUBLIC! ALSO DO NOT COMMIT TO GIT!
            let defaultUserName = "your@email.address"
            let defaultPassword = "secret password"

            userDefaults.setValue(defaultUserName, forKey: "userName_preference")
            userDefaults.setValue(defaultPassword, forKey: "password_preference")
            
            userDefaults.synchronize()
        }
        
        // load settings
        
        sc.userName = userDefaults.string(forKey: "userName_preference")
        sc.password = userDefaults.string(forKey: "password_preference")

        sc.login(){(result:Bool)->() in
            if result {
                self.refreshButton.isEnabled=true
                //self.displayError(errorMessage:"Login to Z.E. services successful")
            } else {
                self.displayError(errorMessage:"Failed to login to Z.E. services.")
                self.refreshButton.isEnabled=true
            }
        }
    }

    @IBOutlet var level: UILabel!
    @IBOutlet var range: UILabel!
    @IBOutlet var update: UILabel!
    @IBOutlet var charger: UILabel!
    @IBOutlet var remaining: UILabel!
    @IBOutlet var charging: UILabel!
    @IBOutlet var plugged: UILabel!
    
    @IBOutlet var refreshButton: UIButton!
    

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
        refreshButton.isEnabled=false;
        
        if (sc.tokenExpiry == nil){ // never logged in successfully
            sc.login(){(result:Bool)->() in
                if (result){
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                } else {
                    self.displayError(errorMessage:"Failed to login to Z.E. services.")
                    self.refreshButton.isEnabled=true;
                }
            }
        } else {
            if sc.isTokenExpired() {
                print("Token expired or will expire too soon (or expiry date is nil), must renew")
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed!")
                        self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                    } else {
                        self.displayError(errorMessage:"Failed to renew expired token.")
                        print("NOT renewed!")
                    }
                }
            } else {
                print("still valid!")
                self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                
            }
        }
    }
    
    
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
        if (error){
            displayError(errorMessage: "Could not obtain battery state.")
            self.refreshButton.isEnabled=true;
        } else {
            self.level.text = String(format: "🔋%3d%%", charge_level)
            self.range.text = String(format: "🛣️ %3.1f km", remaining_range) // 📏
            
            
            //            self.update.text = String(format: "%d", last_update)
            
            self.update.text = self.timestampToDateString(timestamp: last_update)
            if plugged {
                self.charger.text = "⛽️ " + charging_point!
            } else {
                self.charger.text = "⛽️ …"
            }
            
            if charging {
                self.remaining.text = String(format: "⏳ %d min", remaining_time!)
            } else {
                self.remaining.text = "⏳ …"
            }
            self.plugged.text = plugged ? "🔌 ✅" : "🔌 ❌"
            self.charging.text = charging ? "⚡️ ✅" : "⚡️ ❌"
            self.refreshButton.isEnabled=true;
        }
    }



}

