//
//  ViewController.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 01.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import ZEServices
import WatchConnectivity
import os

class ViewController: UIViewController, MapViewControllerDelegate {
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as? MapViewController)?.delegate = self
    }
    
    var rangeForMap:Float?
    func getRemainingRange()->(Float?){
        return rangeForMap
    }

    var percent:UInt8 = 0

    let sc=ServiceConnection.shared

    @IBAction func unwindToViewController(segue: UIStoryboardSegue) {
        //nothing goes here
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("Width = \(self.view.bounds.width), font = \(level.font.pointSize)")
    }


    
    
    fileprivate func performLogin() {

        
        if ((sc.userName == nil) || (sc.password == nil)){
            print ("Enter user credentials in settings app!")
            
            let cancelCallback = {
                UIApplication.shared.open(URL(string : UIApplication.openSettingsURLString)!)
            }
            
            confirmButtonPress(title:"User credentials missing", body:"Press \"Settings\" to be taken directly to the settings app, where you should enter your \"MY Renault\" credentials. Press \"Simulation\" to automatically have special credentials entered for you, that allow using the app in simulation mode.", cancelButton: "Settings", cancelCallback: cancelCallback, confirmButton: "Simulation")
            {
                let userDefaults = UserDefaults.standard
                userDefaults.setValue("simulation", forKey: "userName_preference")
                userDefaults.setValue("simulation", forKey: "password_preference")
                userDefaults.synchronize()
                self.displayMessage(title: "Simulation mode activated", body: "In simulation mode, arbitrary data is displayed and commands are not sent to any real vehicle. To switch to normal mode, go to the settings app and enter your credentials there.")
                NotificationCenter.default.post(name: Notification.Name("applicationDidBecomeActive"), object: nil)
            }
            
            
        } else {
            
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                self.updateActivity(type:.stop)
                if result {
                    print("Login to Z.E. / MY.R. services successful")

                    // auto-refresh after successful login
                    self.updateActivity(type:.start)
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

                    self.updateActivity(type:.start)
                    self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))
                    
                    self.updateActivity(type: .start)
                    self.sc.precondition(command: .read, date: nil, callback: self.preconditionState)

                } else {
                    switch self.sc.api {
                    case .MyRv1, .MyRv2:
                        self.displayMessage(title: "Error", body:"Failed to login to MY.R. services.")
                    case .none:
                        self.displayMessage(title: "Error", body:"Failed to login because API is not set.")
                    }
                }
            }
        }
    }
    
    func userShouldInstallApp(notification: Notification){
        print ("userShouldInstallApp notification received!")
        displayMessage(title: "Info", body: "A watch appears to be paired with this device. Please install the companion app from the Watch app.")

        // confirmButtonPress(title:"Info", body:"Please install WatchApp", cancelButton: "Do not ask again", cancelCallback: {}, confirmButton: "Later"){}
        // need to remember result, but when to reset?
    }
    
    
    func applicationDidBecomeActive(notification: Notification) {
        print ("applicationDidBecomeActive notification received!")
       
        let userDefaults = UserDefaults.standard
        
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
        let new_api = ServiceConnection.ApiVersion(rawValue: userDefaults.integer(forKey: "api_preference"))
       
        if (sc.api != new_api) { // if there is an API change, force new login
            sc.api = new_api
            print("Never started before or API was switched, forcing new login")
            sc.tokenExpiry = nil
        }
        
        // share preferences with widget:
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.set(sc.userName, forKey: "userName")
        sharedDefaults?.set(sc.password, forKey: "password")
        
       
        
        sharedDefaults?.set(sc.api!.rawValue, forKey: "api")
        
        sharedDefaults?.synchronize()
        
        // load settings
        if (sc.tokenExpiry == nil && sc.simulation != true){
            performLogin() // auto-login, if never logged in before
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.shortcutItemToProcess != nil){
            preconditionCar(command: .now, date: nil)
            appDelegate.shortcutItemToProcess = nil // prevent double processing
        }
        
        if traitCollection.userInterfaceStyle == .light {
            print("Light mode")
            self.view.backgroundColor = UIColor.init(red: 0.329, green: 0.894, blue: 1.000, alpha: 1.0)
        } else {
            print("Dark mode")
            self.view.backgroundColor = UIColor.init(red: 0.093, green: 0.254, blue: 0.284, alpha: 1.0)

        }
        
        
        let experimentalFeatures = userDefaults.bool(forKey: "experimental_preference")
        print("experimental features = \(experimentalFeatures)")

        chargeNowButton.isHidden = false

        if (experimentalFeatures){
            mapButton.isHidden = false
        } else {
            mapButton.isHidden = true
        }

    }

    var preconditionRemoteTimer: Date?
    
    @IBAction func startEditing(_ sender: UITextField) {
        print("start")
    }
    @IBOutlet var datePickerView: UIView!
    
    @IBAction func datePickerButtonPressed(_ sender: Any) {
        //datePickerView.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.pickerViewTop.isActive = false
            self.pickerViewBottom.isActive = true
            self.view.layoutIfNeeded()
        }

    }
    @IBOutlet var pickerViewToolbar: UIToolbar!
    @IBOutlet var datePicker: UIDatePicker!
    @IBAction func datePickerDoneButtonPressed(_ sender: Any) {
        UIView.animate(withDuration: 0.3) {
            self.pickerViewBottom.isActive = false
            self.pickerViewTop.isActive = true
            self.view.layoutIfNeeded()
        }
        let preconditionRemoteTimer = datePicker.date
        preconditionCar(command: .later, date: preconditionRemoteTimer)
    }
    @IBAction func datePickerCancelButtonPressed(_ sender: Any) {
        UIView.animate(withDuration: 0.3) {
            self.pickerViewBottom.isActive = false
            self.pickerViewTop.isActive = true
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func datePickerTrashButtonPressed(_ sender: Any) {
        UIView.animate(withDuration: 0.3) {
            self.pickerViewBottom.isActive = false
            self.pickerViewTop.isActive = true
            self.view.layoutIfNeeded()
        }
        preconditionCar(command: .delete, date: nil)

    }
    
    @IBOutlet var datePickerButton: UIButton!
    @IBOutlet var pickerViewTop: NSLayoutConstraint!
    @IBOutlet var pickerViewBottom: NSLayoutConstraint!
       
    var session: WCSession!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        if WCSession.isSupported(){ // do not run on iPad
            session = WCSession.default
            
            
            NotificationCenter.default.addObserver(forName: Notification.Name("userShouldInstallApp"), object: nil, queue: OperationQueue.main, using: {n in self.userShouldInstallApp(notification: n)})
            
        }
        
        // Do any additional setup after loading the view, typically from a nib.
        
        // The following assumes that the labels' font sizes are all adjusted in IB for a 320pts screen width, and it linearly expands the font size to fill the actual width
        var rescaleFactor = self.view.bounds.width / 320.0
        
        if rescaleFactor > 1.5 { // limit size on iPad, as it can otherwise become ridiculously large
            rescaleFactor = 1.5
        }
        print("viewDidLoad: rescaleFactor = \(rescaleFactor)")

        // Note: icon image buttons need to be adjusted using width constraints (corresponding height is defined via ratio constraint in IB)
    
        let chargeNowButtonWidthConstraint = NSLayoutConstraint(item: chargeNowButton!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: rescaleFactor * chargeNowButton.bounds.width)
        let mapButtonWidthConstraint = NSLayoutConstraint(item: mapButton!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: rescaleFactor * mapButton.bounds.width)
        view.addConstraints([chargeNowButtonWidthConstraint, mapButtonWidthConstraint])
        
        level.font = .systemFont(ofSize: level.font.pointSize * rescaleFactor)
        range.font = .systemFont(ofSize: range.font.pointSize * rescaleFactor)
        update.font = .systemFont(ofSize: update.font.pointSize * rescaleFactor)
        charger.font = .systemFont(ofSize: charger.font.pointSize * rescaleFactor)
        remaining.font = .systemFont(ofSize: remaining.font.pointSize * rescaleFactor)
        charging.font = .systemFont(ofSize: charging.font.pointSize * rescaleFactor)
        plugged.font = .systemFont(ofSize: plugged.font.pointSize * rescaleFactor)

        preconditionLast.font = .systemFont(ofSize: preconditionLast.font.pointSize  * rescaleFactor)
        preconditionResult.font = .systemFont(ofSize: preconditionResult.font.pointSize * rescaleFactor)

        datePickerButton.titleLabel?.font = .systemFont(ofSize: (datePickerButton.titleLabel?.font.pointSize)! * rescaleFactor)
        preconditionButton.titleLabel?.font = .systemFont(ofSize: (preconditionButton.titleLabel?.font.pointSize)! * rescaleFactor)
        refreshButton.titleLabel?.font = .systemFont(ofSize: (refreshButton.titleLabel?.font.pointSize)! * rescaleFactor)
        print("viewDidLoad: width = \(view.bounds.width), font = \(level.font.pointSize)")

        
        let toolbarlabel =  UILabel(frame: UIScreen.main.bounds)
        toolbarlabel.text = "A/C timer:"
        toolbarlabel.sizeToFit()
        let toolbarTitle = UIBarButtonItem(customView: toolbarlabel)

        pickerViewToolbar.sizeToFit()
        pickerViewToolbar.setItems([toolbarTitle]+pickerViewToolbar.items!, animated: false)

        NotificationCenter.default.addObserver(forName: Notification.Name("applicationDidBecomeActive"), object: nil, queue: OperationQueue.main, using: {n in self.applicationDidBecomeActive(notification: n)})
        

    }

    //var preconditionRemoteTimer: Date = Date.distantPast
    
    
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
    @IBOutlet var mapButton: UIButton!
    @IBOutlet var preconditionButton: UIButton!
    @IBOutlet var preconditionLast: UILabel!
    @IBOutlet var preconditionResult: UILabel!
    @IBOutlet var temperatureResult: UILabel!
    
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
            activityIndicator.startAnimating()
            activityCount+=1
            os_log("Activity start, count = %{public}d", log: customLog, type: .default, activityCount)
            break
        case .stop:
            activityCount-=1
            os_log("Activity stop, count = %{public}d", log: customLog, type: .default, activityCount)
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
        //print("Activity count = \(activityCount)")
    }

    func handleLogin(onError errorCode:@escaping()->Void, onSuccess actionCode:@escaping()->Void) {
               
        if (sc.tokenExpiry == nil){ // never logged in successfully
        
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                if (result){
                    actionCode()
                } else {
                    switch self.sc.api {
                    case .MyRv1, .MyRv2:
                        self.displayMessage(title: "Error", body:"Failed to login to MY.R. services.")
                    case .none:
                        self.displayMessage(title: "Error", body:"Failed to login because API is not set.")
                    }
                    errorCode()
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
                        actionCode()
                    } else {
                        print("expired token NOT renewed!")
                        self.sc.tokenExpiry = nil // force new login next time
                        // instead of error, attempt new login right now:
                        self.updateActivity(type:.start)
                        self.sc.login(){(result:Bool)->() in
                            if (result){
                                actionCode()
                            } else {
                                self.displayMessage(title: "Error", body:"Failed to renew expired token and to login to Z.E. services.")
                                errorCode()
                            }
                            self.updateActivity(type:.stop)
                        }
                    }
                    self.updateActivity(type:.stop)
                }
            } else {
                print("token still valid!")
                actionCode()
            }
        }
    }
    
    
    
    
    var count = 0

    @IBAction func refreshButtonPressed(_ sender: UIButton) {
                
        handleLogin(onError: {}){
            self.updateActivity(type:.start)
            self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

            self.updateActivity(type:.start)
            self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))
            
            self.updateActivity(type: .start)
            self.sc.precondition(command: .read, date: nil, callback: self.preconditionState)
        }
    }
    
    
    
    
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain battery state.")
            
        } else {
            level.text = String(format: "🔋%3d%%", charge_level)
            if (remaining_range >= 0.0){
            range.text = String(format: "🛣️ %3.0f km", remaining_range.rounded()) // 📏
            rangeForMap = remaining_range * 1000.0
            } else {
                range.text = String(format: "🛣️ …") // 📏
                rangeForMap = nil
            }
            update.text = timestampToDateString(timestamp: last_update)
           
            
            charger.text = chargingPointToChargerString(plugged, charging_point)
            
            if charging, remaining_time != nil {
                remaining.text = String(format: "⏳ %d min.", remaining_time!)
            } else {
                remaining.text = "⏳ …"
            }
            self.plugged.text = plugged ? "🔌 ✅" : "🔌 ❌"
            self.charging.text = charging ? "⚡️ ✅" : "⚡️ ❌"
        }

        updateActivity(type:.stop)
    }

    
    func acLastState(error: Bool, date:UInt64, type:String?, result:String?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain A/C last state.")
            
        } else {
            if date != 0 , result != nil {
                preconditionLast.text = timestampToDateString(timestamp: date)
                switch (result!) {
                case "ERROR":
                    preconditionResult.text = "🌬 ❌"
                    break
                case "SUCCESS":
                    preconditionResult.text = "🌬 ✅"
                    break
                default:
                    preconditionResult.text = "🌬 …"
                }
            } else {
                preconditionResult.text = "🌬 …"
            }
        }
        updateActivity(type:.stop)
    }
        
    
    func preconditionState(error: Bool, command:PreconditionCommand, date: Date?, externalTemperature: Float? )->(){
        print("Precondition returns \(error)")
        switch command {
        case .now:
            if (error){
                displayMessage(title: "Error", body: "Could not request to turn on A/C.")
            } else {
                displayMessage(title: "Success", body: "Requested to turn on A/C.")
            }
            preconditionButton.isEnabled=true
            
        case .later, .read, .delete:
            preconditionRemoteTimer = date // save current value, so the text field can be quickly restored
            if (!error){
                if (date != nil){
                    datePickerButton.setTitle(dateToTimeString(date: date!), for: .normal)
                } else {
                    datePickerButton.setTitle("⏰ --:--", for: .normal)

                }
            } else {
                datePickerButton.setTitle("⏰ error", for: .normal)
            }
            if command == .read && externalTemperature != nil {
                temperatureResult.text = "🌡 \(externalTemperature!)°"
            }
        }
        
        updateActivity(type: .stop)
    }

    
    func preconditionCar(command:PreconditionCommand, date: Date?){
        handleLogin(onError: {self.preconditionButton.isEnabled=true}){
            self.updateActivity(type: .start)
            self.sc.precondition(command: command, date: date, callback: self.preconditionState)
        }
    }
    
    @IBAction func preconditionButtonPressed(_ sender: Any) {
        preconditionButton.isEnabled=false
        print("Precondition")

        confirmButtonPress(title:"Turn on air-conditioning?", body:"The car will immediately turn on A/C and leave it running for a couple of minutes.", cancelButton: "Cancel", cancelCallback: {self.preconditionButton.isEnabled=true}, confirmButton: "Turn on A/C"){
                self.preconditionCar(command: .now, date: nil)
        }
    }
    

    
    @IBOutlet var chargeNowButton: UIButton!
    @IBAction func chargeNowButtonPressed(_ sender: Any) {
        self.chargeNowButton.isEnabled=false
        print("request to charge!")
            
        confirmButtonPress(title:"Charge pause override?", body:"Will tell the car to ignore any scheduled charging pause and to start charging immediately.", cancelButton: "Cancel", cancelCallback: {self.chargeNowButton.isEnabled=true}, confirmButton: "Start charging")
        {
            
            self.handleLogin(onError: {self.chargeNowButton.isEnabled=true}){
                self.updateActivity(type:.start)
                self.sc.chargeNowRequest(callback: self.chargeNowRequest(error:))
            }
        }
    }
    
    func chargeNowRequest(error: Bool)->(){
        self.chargeNowButton.isEnabled=true
        if (error){
            displayMessage(title: "Error", body: "Could not request to start charging.")
            
        } else {
            displayMessage(title: "Success", body: "Requested to start charging.")
        }
        updateActivity(type:.stop)
    }
}

