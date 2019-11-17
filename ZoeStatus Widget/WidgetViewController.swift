//
//  TodayViewController.swift
//  ZoeStatus Widget
//
//  Created by Dr. Guido Mocken on 15.11.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import NotificationCenter

var levelCache:UInt8?
var remainingRangeCache:Float?

class WidgetViewController: UIViewController, NCWidgetProviding {
        
    var sc=ServiceConnection()
    

    fileprivate func displayMessage(title: String, body: String) {
        print("Alert: \(title) \(body)")
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.synchronize()
        let userName = sharedDefaults?.string(forKey:"userName")
        let password = sharedDefaults?.string(forKey:"password")

       //print("\(userName) \(password)")
        
        
        ServiceConnection.userName = userName
        ServiceConnection.password = password
        if ServiceConnection.userName == "simulation", ServiceConnection.password == "simulation"
        {
            ServiceConnection.simulation = true
        } else {
            ServiceConnection.simulation = false
        }

        if (ServiceConnection.tokenExpiry == nil){
            
            sc.login(){(result:Bool)->() in
                self.updateActivity(type:.stop)
                if result {
                    self.refreshButtonPressed(self.refreshButton) // auto-refresh after successful login
                    print("Login to Z.E. services successful")
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                }
            }
        }
        
    }
    
    
    enum startStop {
        case start, stop
    }
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var activityCount: Int = 0
    
    func updateActivity(type:startStop){

        switch type {
        case .start:
            refreshButton.isEnabled=false
            refreshButton.isHidden=true
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
            }
            break
        }
        print("Activity count = \(activityCount)")
    }


    
        
    @IBOutlet var level: UILabel!
    @IBOutlet var range: UILabel!
    @IBOutlet var refreshButton: UIButton!
    @IBAction func refreshButtonPressed(_ sender: UIButton) {
       
        if (ServiceConnection.tokenExpiry == nil){ // never logged in successfully
        
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                if (result){
                    self.updateActivity(type:.start)
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

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
            }
        }
    }

    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        print("widgetPerformUpdate!")

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        if levelCache != nil {
            self.level.text = String(format: "🔋%3d%%", levelCache!)
        }
        if (remainingRangeCache != nil){
            self.range.text = String(format: "🛣️ %3.0f km", remainingRangeCache!)
        }
        completionHandler(NCUpdateResult.noData)
    }
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain battery state.")
            
        } else {
                        
            self.level.text = String(format: "🔋%3d%%", charge_level)
            levelCache = charge_level
            self.range.text = String(format: "🛣️ %3.0f km", remaining_range)
            remainingRangeCache = remaining_range
            
        }
        updateActivity(type:.stop)

    }
}
