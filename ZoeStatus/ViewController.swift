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

        sc.login()


    }

    @IBOutlet var batteryState: UILabel!
    
    

    @IBAction func refreshButtonPressed(_ sender: Any) {
        
        sc.batteryState(delegate:self)
        
       
    }
 
}

