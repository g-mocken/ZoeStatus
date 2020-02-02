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
        let api = sharedDefaults?.integer(forKey: "api")
       //print("\(userName) \(password)")
        
        // launch app on tap in widget
        let tap = UITapGestureRecognizer(target: self, action: #selector(launchApp(_:)))
        // attach to only part of widget:
        // level.addGestureRecognizer(tap)
        // level.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(tap) // attach to whole widget view

        
        
        sc.userName = userName
        sc.password = password
        sc.api = ServiceConnection.ApiVersion(rawValue: api!)

        if sc.userName == "simulation", sc.password == "simulation"
        {
            sc.simulation = true
        } else {
            sc.simulation = false
        }

        if (sc.tokenExpiry == nil){
            
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
    @IBOutlet var update: UILabel!
    @IBOutlet var refreshButton: UIButton!
    @IBAction func refreshButtonPressed(_ sender: UIButton) {
        
        if (sc.tokenExpiry == nil){ // never logged in successfully
        
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
                        self.sc.tokenExpiry = nil // force new login next time
                        print("expired token NOT renewed!")
                        // instead of error, attempt new login right now:
                        self.updateActivity(type:.start)
                        self.sc.login(){(result:Bool)->() in
                            if (result){
                                self.updateActivity(type:.start)
                                self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

                            } else {
                                self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                            }
                            self.updateActivity(type:.stop)
                        }
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
        if remainingRangeCache != nil {
            self.range.text = String(format: "🛣️ %3.0f km", remainingRangeCache!)
        }
        if last_update_cache != nil {
            self.update.text = timestampToDateString(timestamp: last_update_cache!)
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
            
            self.update.text = timestampToDateString(timestamp: last_update)
            last_update_cache = last_update

            
        }
        updateActivity(type:.stop)

    }
}
