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
                print("YES!")
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
    

    @IBAction func refreshButtonPressed(_ sender: Any) {
        sc.batteryState(callback: {(charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->() in
            self.level.text = String(format: "%3d%%", charge_level)
            self.range.text = String(format: "%3.1f km", remaining_range)
            self.update.text = String(format: "%d", last_update)
            if plugged {
                self.charger.text = charging_point!
            }
            if charging {
                self.remaining.text = String(format: "%d", remaining_time!)
            }
            self.plugged.text = plugged ? "Plugged in" : "Not plugged in"
            self.charging.text = charging ? "Charging" : "Not charging"

        })
    }
 
}

