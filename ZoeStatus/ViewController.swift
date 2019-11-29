//
//  ViewController.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 01.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import UIKit


class ViewController: UIViewController, MapViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as? MapViewController)?.delegate = self
    }
    
    var rangeForMap:Float?
    func getRemainingRange()->(Float?){
        return rangeForMap
    }

    var percent:UInt8 = 0

    var sc=ServiceConnection()
   
    @IBAction func unwindToViewController(segue: UIStoryboardSegue) {
        //nothing goes here
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("Width = \(self.view.bounds.width), font = \(level.font.pointSize)")
    }

    fileprivate func performLogin() {

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
        
        ServiceConnection.userName = userDefaults.string(forKey: "userName_preference")
        ServiceConnection.password = userDefaults.string(forKey: "password_preference")
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.set(ServiceConnection.userName, forKey: "userName")
        sharedDefaults?.set(ServiceConnection.password, forKey: "password")
        sharedDefaults?.synchronize()


        
        if ((ServiceConnection.userName == nil) || (ServiceConnection.password == nil)){
            print ("Enter user credentials in settings app!")
            UIApplication.shared.open(URL(string : UIApplication.openSettingsURLString)!)
        } else {

            if ServiceConnection.userName == "simulation", ServiceConnection.password == "simulation"
            {
                ServiceConnection.simulation = true
            } else {
                ServiceConnection.simulation = false
            }
            
            updateActivity(type:.start)
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
    
    @objc func applicationDidBecomeActive(notification: Notification) {
        print ("applicationDidBecomeActive notification received!")
       
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if ( appDelegate.shortcutItemToProcess != nil){
            if preconditionTimer == nil { // avoid double start
                preconditionCar(command: .now, date: nil)
            }
            appDelegate.shortcutItemToProcess = nil // prevent double processing
        }
        
        if traitCollection.userInterfaceStyle == .light {
            print("Light mode")
            self.view.backgroundColor = UIColor.init(red: 0.329, green: 0.894, blue: 1.000, alpha: 1.0)
        } else {
            print("Dark mode")
            self.view.backgroundColor = UIColor.init(red: 0.093, green: 0.254, blue: 0.284, alpha: 1.0)

        }
        
        
        let userDefaults = UserDefaults.standard
        let experimentalFeatures = userDefaults.bool(forKey: "experimental_preference")
        print("experimental features = \(experimentalFeatures)")

        chargeNowButton.isHidden = false

        if (experimentalFeatures){
            mapButton.isHidden = false
        } else {
            mapButton.isHidden = true
        }

        // load settings
        if (ServiceConnection.tokenExpiry == nil){
            performLogin()
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
       
    override func viewDidLoad() {
        super.viewDidLoad()
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
        preconditionTime.font = .systemFont(ofSize: preconditionTime.font.pointSize * rescaleFactor)

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

     
        NotificationCenter.default.removeObserver(self, name: Notification.Name("applicationDidBecomeActive"), object: nil) // remove if already present, in order to avoid double registration
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive(notification:)), name: Notification.Name("applicationDidBecomeActive"), object: nil)

        
        // add guesture recognizer
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        refreshButton.addGestureRecognizer(longPress)

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


    @IBAction func refreshButtonPressed(_ sender: UIButton) {
               
        if (ServiceConnection.tokenExpiry == nil){ // never logged in successfully
        
            updateActivity(type:.start)
            sc.login(){(result:Bool)->() in
                if (result){
                    self.updateActivity(type:.start)
                    self.sc.batteryState(callback: self.batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))

                    self.updateActivity(type:.start)
                    self.sc.airConditioningLastState(callback:self.acLastState(error:date:type:result:))
                    
                    self.updateActivity(type: .start)
                    self.sc.precondition(command: .read, date: nil, callback: self.preconditionState)

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

                        self.updateActivity(type: .start)
                        self.sc.precondition(command: .read, date: nil, callback: self.preconditionState)

                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        print("expired token NOT renewed!")
                    }
                    self.updateActivity(type:.stop)
                }
            } else {
                print("token still valid!")
            
                updateActivity(type:.start)
                sc.batteryState(callback: batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:))
                updateActivity(type:.start)
                sc.airConditioningLastState(callback:acLastState(error:date:type:result:))

                updateActivity(type: .start)
                sc.precondition(command: .read, date: nil, callback: preconditionState)

            }
        }
    }
    
    
    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not obtain battery state.")
            
        } else {
            level.text = String(format: "🔋%3d%%", charge_level)
            range.text = String(format: "🛣️ %3.0f km", remaining_range.rounded()) // 📏
            rangeForMap = remaining_range * 1000.0
            
            update.text = timestampToDateString(timestamp: last_update)
            if plugged, charging_point != nil {
                
                switch (charging_point!) {
                case "INVALID":
                    charger.text = "⛽️ " + "❌"
                    break;
                case "SLOW":
                    charger.text = "⛽️ " + "🐌"
                    break;
                case "FAST":
                    charger.text = "⛽️ " + "✈️"
                    break;
                case "ACCELERATED":
                    charger.text = "⛽️ " + "🚀"
                    break;
                default:
                    charger.text = "⛽️ " + charging_point!
                    break;
                }
            } else {
                charger.text = "⛽️ …"
            }
            
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
                    preconditionResult.text = "🌡 ❌"
                    break
                case "SUCCESS":
                    preconditionResult.text = "🌡 ✅"
                    break
                default:
                    preconditionResult.text = "🌡 …"
                }
            } else {
                preconditionResult.text = "🌡 …"
            }
        }
        updateActivity(type:.stop)
    }
        
    var preconditionTimer: Timer?
    
    func preconditionState(error: Bool, command:ServiceConnection.PreconditionCommand, date: Date?)->(){
        print("Precondition returns \(error)")
        switch command {
        case .now:
            if (!error){
                // success, start countdown timer
                let userDefaults = UserDefaults.standard
                let preconditionTimerCountdown = userDefaults.integer(forKey: "countdown_preference")
                print ("countdown in seconds = \(preconditionTimerCountdown)")
                let timerStartDate = Date.init() // current date & time
                
                preconditionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
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
                // on error
                preconditionTime.isHidden=true
                preconditionButton.isEnabled=true
                preconditionButton.isHidden=false
            }
            
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
        }
        
        updateActivity(type: .stop)
    }


    
    func preconditionCar(command:ServiceConnection.PreconditionCommand, date: Date?){
        if (ServiceConnection.tokenExpiry == nil){ // never logged in successfully
            updateActivity(type: .start)
            sc.login(){(result:Bool)->() in
                if (result){
                    self.updateActivity(type: .start)
                    self.sc.precondition(command: command, date: date, callback: self.preconditionState)
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to Z.E. services.")
                    self.preconditionButton.isEnabled=true
                }
                self.updateActivity(type: .stop)
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                updateActivity(type:.start)
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
                        self.updateActivity(type:.start)
                        self.sc.precondition(command: command, date: date, callback: self.preconditionState)

                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        self.preconditionButton.isEnabled=true
                        print("expired token NOT renewed!")
                    }
                }
                updateActivity(type:.stop)
            } else {
                print("token still valid!")
                updateActivity(type: .start)
                sc.precondition(command: command, date: date, callback: self.preconditionState)
            }
        }
    }
    
    @IBAction func preconditionButtonPressed(_ sender: Any) {
        print("Precondition")
        
        
        preconditionButton.isEnabled=false;
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                          style: .cancel) { (action) in
                                            {self.preconditionButton.isEnabled=true}()
        }

        let confirmAction = UIAlertAction(title: "Turn on A/C",
                                         style: .default) { (action) in
                                            if self.preconditionTimer == nil {
                                                self.preconditionCar(command: .now, date: nil)
                                            }
        }
        
        let alert = UIAlertController(title: "Turn on air-conditioning?", message: "The car will immediately turn on A/C and leave it running for a couple of minutes. A configurable countdown will be displayed in place of the trigger button.", preferredStyle: .alert)
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)

        
        self.present(alert, animated: true) {
            // The alert was presented
        }
    }
    


    
    @objc func longPress(_ guesture: UILongPressGestureRecognizer) {
        if guesture.state == UIGestureRecognizer.State.began {
            
            print("request state after long press of refresh!")
            confirmButtonPress(title:"Request battery state update?", body:"Will instruct the back-end to fetch a battery state update from the car.", cancelButton: "Cancel", cancelCallback: { }, confirmButton: "Update")
            {
                // trailing confirmCallback-closure:
                self.updateActivity(type:.start)
                self.sc.batteryStateUpdateRequest(callback: self.batteryStateUpdateRequest(error:))
            }
        }
    }
    
    func batteryStateUpdateRequest(error: Bool)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not request battery state, probably because of rate limiting by the back-end.")
            
        } else {
            displayMessage(title: "Successfully requested battery state update.", body: "The request may take several minutes to complete or fail entirely. Depending on configuration, a text message or email may be triggered. To fetch the updated state from the back-end, use the refresh button.")
        }
        updateActivity(type:.stop)
    }
    
    @IBOutlet var chargeNowButton: UIButton!
    @IBAction func chargeNowButtonPressed(_ sender: Any) {
        
        print("request to charge!")
            
        confirmButtonPress(title:"Charge pause override?", body:"Will tell the car to ignore any scheduled charging pause and to start charging immediately.", cancelButton: "Cancel", cancelCallback: {/*self.chargeNowButton.isEnabled=true*/}, confirmButton: "Start charging")
        {
            // trailing confirmCallback-closure:
            self.updateActivity(type:.start)
            self.sc.chargeNowRequest(callback: self.chargeNowRequest(error:))
        }

        
    }
    
    func chargeNowRequest(error: Bool)->(){
        
        if (error){
            displayMessage(title: "Error", body: "Could not request to start charging.")
            
        } else {
            displayMessage(title: "Success", body: "Requested to start charging.")
        }
        updateActivity(type:.stop)
    }
}

