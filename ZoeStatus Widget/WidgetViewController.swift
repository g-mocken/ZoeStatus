//
//  TodayViewController.swift
//  ZoeStatus Widget
//
//  Created by Dr. Guido Mocken on 15.11.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import NotificationCenter
import ZEServices

var levelCache:UInt8?
var remainingRangeCache:Float?
var last_update_cache:UInt64?

class WidgetViewController: UIViewController, NCWidgetProviding {
        
    let sc=ServiceConnection.shared
    

    fileprivate func displayMessage(title: String, body: String) {
        print("Alert: \(title) \(body)")
    }

    @objc func launchApp(_ guesture: UILongPressGestureRecognizer){
        let url: NSURL = NSURL(string: "ZoeStatus://")!
        self.extensionContext?.open(url as URL, completionHandler: nil)
        print("launching app")

    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("transition width= \(size.width)")
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    
    
    var levelFontSize:CGFloat = 0
    var rangeFontSize:CGFloat = 0
    var updateFontSize:CGFloat = 0
    var refreshFontSize:CGFloat = 0

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        print("layout width = \(self.view.bounds.width)")
       
        let rescaleFactor = self.view.bounds.width / 320.0 // correct factor even on iPad!
        level.font = .systemFont(ofSize: levelFontSize * rescaleFactor)
        range.font = .systemFont(ofSize: rangeFontSize * rescaleFactor)
        update.font = .systemFont(ofSize: updateFontSize * rescaleFactor)
        refreshButton.titleLabel?.font = .systemFont(ofSize: refreshFontSize * rescaleFactor)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        // The following assumes that the labels' font sizes are all adjusted in IB for a 320pts screen width, and it linearly expands the font size to fill the actual width
       
        print("width = \(self.view.bounds.width)")
        
        // rescaling here does not work on iPad, because the factor is wrong then:
        //let rescaleFactor = self.view.bounds.width / 320.0
        //        level.font = .systemFont(ofSize: level.font.pointSize * rescaleFactor)
        //        range.font = .systemFont(ofSize: range.font.pointSize * rescaleFactor)
        //        update.font = .systemFont(ofSize: update.font.pointSize * rescaleFactor)
        //        refreshButton.titleLabel?.font = .systemFont(ofSize: (refreshButton.titleLabel?.font.pointSize)! * rescaleFactor)

        // save point sizes and do rescaling later
        levelFontSize=level.font.pointSize
        rangeFontSize=range.font.pointSize
        updateFontSize=update.font.pointSize
        refreshFontSize = (refreshButton.titleLabel?.font.pointSize)!
        
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.synchronize()
        let userName = sharedDefaults?.string(forKey:"userName")
        let password = sharedDefaults?.string(forKey:"password")
        let _ = sharedDefaults?.integer(forKey: "api")
        let units = sharedDefaults?.integer(forKey: "units")
        let kamereon = sharedDefaults?.string(forKey: "kamereon")
        let vehicle = sharedDefaults?.integer(forKey: "vehicle")
       //print("\(userName) \(password)")
        
        // launch app on tap in widget
        let tap = UITapGestureRecognizer(target: self, action: #selector(launchApp(_:)))
        // attach to only part of widget:
        // level.addGestureRecognizer(tap)
        // level.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(tap) // attach to whole widget view

        
        
        sc.userName = userName
        sc.password = password
        sc.api = ServiceConnection.ApiVersion(rawValue: 1 /*api!*/) // dummy value 1, which is ignored
        /* Renault is no longer using a consistent version, i.e. battery state only works as v2 and cockpit as v1. */
        sc.units = ServiceConnection.Units(rawValue: units!)
        sc.kamereon = kamereon
        sc.vehicle = vehicle
        
        if sc.userName == "simulation", sc.password == "simulation"
        {
            sc.simulation = true
        } else {
            sc.simulation = false
        }
        
        /*
        if (sc.tokenExpiry == nil){
            
            sc.login(){(result:Bool, errorMessage:String?)->() in
                self.updateActivity(type:.stop)
                if result {
                    self.refreshButtonPressed(self.refreshButton) // auto-refresh after successful login
                    print("Login to MY.R. services successful")
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(errorMessage!))")
                }
            }
        }
        */
        // async variant
        
        updateActivity(type:.start)
        Task {
            if (sc.tokenExpiry == nil){
                
                let r = await sc.loginAsync()
                updateActivity(type:.stop)
                if r.result {
                    refreshButtonPressed(refreshButton) // auto-refresh after successful login
                    print("Login to MY.R. services successful")
                } else {
                    displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(r.errorMessage!))")
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
    @IBOutlet var update: UILabel!
    @IBOutlet var refreshButton: UIButton!
    @IBAction func refreshButtonPressed(_ sender: UIButton) {
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.synchronize()
        let newVehicle = sharedDefaults?.integer(forKey: "vehicle")
        if (sc.vehicle != newVehicle){
            sc.vehicle = newVehicle
            print("Never started before or vehicle was switched, forcing new login")
            sc.tokenExpiry = nil
        }

        
        // async variant

        updateActivity(type:.start) // start animation on main thread
        Task {
            if (sc.tokenExpiry == nil){ // never logged in successfully
                
                let r = await sc.loginAsync()
                if (r.result){
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                } else {
                    displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(r.errorMessage!))")
                    level.text = "🔋…"
                    range.text = "🛣️ …"
                    update.text = timestampToDateString(timestamp: nil)
                }
                
            } else {
                if sc.isTokenExpired() {
                    //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                    let result = await sc.renewTokenAsync()
                    
                    if result {
                        print("renewed expired token!")
                        let bs = await sc.batteryStateAsync()
                        batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                    } else {
                        displayMessage(title: "Error", body:"Failed to renew expired token.")
                        sc.tokenExpiry = nil // force new login next time
                        print("expired token NOT renewed!")
                        
                        // instead of error, attempt new login right now:
                        let r = await sc.loginAsync()
                        
                        if (r.result){
                            let bs = await sc.batteryStateAsync()
                            batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                        } else {
                            displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(r.errorMessage!))")
                        }
                    }
                    
                } else {
                    print("token still valid!")
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                }
            }
            //updateActivity(type:.stop)
        }
    }

    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        print("widgetPerformUpdate!")

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        if levelCache != nil {
            level.text = String(format: "🔋%3d%%", levelCache!)
        }
        if remainingRangeCache != nil {
            if (sc.units == .Metric){
                range.text = String(format: "🛣️ %3.0f km", remainingRangeCache!)
            } else {
                range.text = String(format: "🛣️ %3.0f mi", remainingRangeCache!/sc.kmPerMile)
            }
            
        }
        if last_update_cache != nil {
            update.text = timestampToDateString(timestamp: last_update_cache!)
        }
        
        completionHandler(NCUpdateResult.noData)
    }
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?, battery_temperature:Int?, vehicle_id:String?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain battery state.")
            
        } else {
                        
            level.text = String(format: "🔋%3d%%", charge_level)
            levelCache = charge_level
            if (remaining_range >= 0.0){
                
                if (sc.units == .Metric){
                    range.text = String(format: "🛣️ %3.0f km", remaining_range.rounded())
                } else {
                    range.text = String(format: "🛣️ %3.0f mi", (remaining_range/sc.kmPerMile).rounded())
                }

                
            } else {
                    range.text = String(format: "🛣️ …")
            }
            remainingRangeCache = remaining_range
            
            update.text = timestampToDateString(timestamp: last_update)
            last_update_cache = last_update

            
        }
        updateActivity(type:.stop)
    }
}
