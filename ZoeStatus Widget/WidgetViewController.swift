//
//  TodayViewController.swift
//  ZoeStatus Widget
//
//  Created by Dr. Guido Mocken on 15.11.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import NotificationCenter


class WidgetViewController: UIViewController, NCWidgetProviding {
        
    var sc=ServiceConnection()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
        
    @IBOutlet var level: UILabel!
    @IBOutlet var range: UILabel!
    @IBAction func refreshButton(_ sender: Any) {
       
        if (ServiceConnection.tokenExpiry == nil){ // never logged in successfully
        
         //   updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                if (result){
           //         self.updateActivity(type:.start)
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

                } else {
          //          self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                }
             //   self.updateActivity(type:.stop)
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
           //     updateActivity(type:.start)
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
             //           self.updateActivity(type:.start)
                        self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                        
                    } else {
         //               self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        print("expired token NOT renewed!")
                    }
                //    self.updateActivity(type:.stop)
                }
            } else {
                print("token still valid!")
            
         //       updateActivity(type:.start)
                self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
            }
        }
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
           if (error){
                  // displayMessage(title: "Error", body: "Could not obtain battery state.")
                   
               } else {
                   self.level.text = String(format: "🔋%3d%%", charge_level)
                   self.range.text = String(format: "🛣️ %3.0f km", remaining_range) // 📏
                   
        }
    }
}
