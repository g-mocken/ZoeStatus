//
//  IntentHandler.swift
//  ZoeStatus Intents Extension
//
//  Created by Dr. Guido Mocken on 05.10.22.
//  Copyright © 2022 Dr. Guido Mocken. All rights reserved.
//

import Intents
import ZEServices
import os.log

class IntentHandlerCarList: INExtension,INListCarsIntentHandling {
    
    

    func confirm(intent: INListCarsIntent, completion: @escaping (INListCarsIntentResponse) -> Void) {
        // Confirms that you can provide a list of the user’s electric vehicles.

        print("confirming... \(intent)")
        let response = INListCarsIntentResponse(code: INListCarsIntentResponseCode.ready, userActivity: nil)
        completion(response)
    }
    
    func handle(intent: INListCarsIntent, completion: @escaping (INListCarsIntentResponse) -> Void) {
        // Provides a list of the user’s electric vehicles.

        print("handling... \(intent)")
        let response = INListCarsIntentResponse(code: INListCarsIntentResponseCode.success, userActivity: nil)
        response.cars = [INCar(carIdentifier: "VIN", displayName: "ZOE", year: "2014", make: "Renault", model: "Q210", color: nil, headUnit: nil, supportedChargingConnectors: [INCar.ChargingConnectorType.mennekes])]
        completion(response)

        
    }
   
    
}

class IntentHandlerPowerLevel:INExtension, INGetCarPowerLevelStatusIntentHandling {
    
    let sc=ServiceConnection.shared

    var observer:INGetCarPowerLevelStatusIntentResponseObserver?
    
    func resolveCarName(for intent: INGetCarPowerLevelStatusIntent, with completion: @escaping (INSpeakableStringResolutionResult) -> Void) {
        print("resolving... \(intent)")
        print("Car name: \(String(describing: intent.carName)) ")

        
        let result: INSpeakableStringResolutionResult

        
        if let carName = intent.carName {

            result = INSpeakableStringResolutionResult.success(with: carName)

//            if (
//                ( carName == INSpeakableString(spokenPhrase: "Renault Zoe") ) ||
//                ( carName == INSpeakableString(spokenPhrase: "Renault") ) ||
//                ( carName == INSpeakableString(spokenPhrase: "Zoe") )
//            ){
//                result = INSpeakableStringResolutionResult.confirmationRequired(with: carName)
//
//            } else {
//                result = INSpeakableStringResolutionResult.unsupported()
//            }
        }
        else {
            // result = INSpeakableStringResolutionResult.needsValue()
            result = INSpeakableStringResolutionResult.success(with: INSpeakableString(spokenPhrase: "Renault Zoë"))

        }
        
  
        completion(result)


    }
    
    func confirm(intent: INGetCarPowerLevelStatusIntent, completion: @escaping (INGetCarPowerLevelStatusIntentResponse) -> Void) {
        print("confirming... \(intent)")
        
        let response = INGetCarPowerLevelStatusIntentResponse(code: .ready, userActivity: nil)
        

        completion(response)
    }


    func handle(intent: INGetCarPowerLevelStatusIntent, completion: @escaping (INGetCarPowerLevelStatusIntentResponse) -> Void) {
        
        print("handling... \(intent)")

        print("Car name: \(String(describing: intent.carName)) ")
        
        
                
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.synchronize()
        sc.userName = sharedDefaults?.string(forKey:"userName")
        sc.password = sharedDefaults?.string(forKey:"password")
        sc.api = ServiceConnection.ApiVersion(rawValue: (sharedDefaults?.integer(forKey: "api"))!)
        sc.units = ServiceConnection.Units(rawValue: (sharedDefaults?.integer(forKey: "units"))!)
        sc.kamereon = sharedDefaults?.string(forKey: "kamereon")
        sc.vehicle = sharedDefaults?.integer(forKey: "vehicle")
        
        if sc.userName == "simulation", sc.password == "simulation"
        {
            sc.simulation = true
        } else {
            sc.simulation = false
        }

        
        
        let actionCode = {
            
            Task {
                let bs = await self.sc.batteryStateAsync()
                
                let response = INGetCarPowerLevelStatusIntentResponse(code: INGetCarPowerLevelStatusIntentResponseCode.success, userActivity: nil)
                
                
                response.charging = bs.charging
                response.chargePercentRemaining = Float(bs.charge_level)/100.0 // 0.12 = 12%
                response.distanceRemaining = Measurement(value: Double(bs.remaining_range), unit: UnitLength.kilometers)
                if #available(iOSApplicationExtension 14.0, *) {
                    response.activeConnector =  INCar.ChargingConnectorType.mennekes
                } else {
                    // Fallback on earlier versions
                }
                if #available(iOSApplicationExtension 14.0, *) {
                    response.carIdentifier = bs.vehicle_id
                } else {
                    // Fallback on earlier versions
                }
                // response.distanceRemainingElectric = Measurement(value: Double(200.0), unit: UnitLength.kilometers)
                // response.currentBatteryCapacity  = Measurement(value: Double(22.0), unit: UnitEnergy.kilowattHours)
                
                completion(response)
            }
        }
        let errorCode = {
            print("Error")
            let response = INGetCarPowerLevelStatusIntentResponse(code: INGetCarPowerLevelStatusIntentResponseCode.failure, userActivity: nil)
            completion(response)
        }
        
        
        
        /*
        
        if (sc.tokenExpiry == nil){
            print("Never logged in before")
            sc.login(){(result:Bool, errorMessage:String?)->() in
                if result {
                    print("Login successful")
                    actionCode()
                } else {
                    print("Login NOT successful")
                    errorCode()
                }
            }
        } else {
            print("Did log in before, checking token")
            if sc.isTokenExpired() { // token expired
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
                        actionCode()
                    } else {
                        print("expired token NOT renewed!")
                        errorCode()
                    }
                }
            } else { // token valid
                actionCode()
            }
        }
        */
        
        
        // async variant
        Task{
            if (sc.tokenExpiry == nil){
                print("Never logged in before")
                let r = await sc.loginAsync()
                if r.result {
                    print("Login successful")
                    _ = actionCode()
                } else {
                    print("Login NOT successful")
                    errorCode()
                }
                
            } else {
                print("Did log in before, checking token")
                if sc.isTokenExpired() { // token expired
                    let result = await sc.renewTokenAsync()
                    if result {
                        print("renewed expired token!")
                        _ = actionCode()
                    } else {
                        print("expired token NOT renewed!")
                        errorCode()
                    }
                } else { // token valid
                    _ = actionCode()
                }
            }
        }
        
    }
    
    

    
    func startSendingUpdates(for intent: INGetCarPowerLevelStatusIntent, to observer: INGetCarPowerLevelStatusIntentResponseObserver) {
        print("startSendingUpdates")
        /* Maps calls this method when it begins a navigation session, and you must use the observer to inform Maps of any abrupt changes in the electric vehicle’s battery charge. */
        self.observer = observer
        let response = INGetCarPowerLevelStatusIntentResponse(code: INGetCarPowerLevelStatusIntentResponseCode.success, userActivity: nil)
        
        // TODO: set up a timer to periodically call:
        response.charging = false
        response.chargePercentRemaining = Float(12)/100.0 // e.g. 0.12 = 12%
        response.distanceRemaining = Measurement(value: Double(123), unit: UnitLength.kilometers)
            response.activeConnector =  INCar.ChargingConnectorType.mennekes
        observer.didUpdate(getCarPowerLevelStatus: response)
    }
    
    func stopSendingUpdates(for intent: INGetCarPowerLevelStatusIntent) {
        print("stopSendingUpdates")
        // stop timer and callbacks
    }
}


class IntentHandler: INExtension {
    
    let subsystem = Bundle.main.bundleIdentifier! //"com.grm.ZoeStatus"
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ZOE")

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.

        print("handle \(intent)")
        os_log("Handling INListCarsIntent", log: log, type: .info)

        if #available(iOSApplicationExtension 14.0, *) {
            switch intent {
            case is INGetCarPowerLevelStatusIntent: return IntentHandlerPowerLevel()
            case is INListCarsIntent: return IntentHandlerCarList()
            default: break
            }
        } else {
            // Fallback on earlier versions
            switch intent {
                case is INGetCarPowerLevelStatusIntent: return IntentHandlerPowerLevel()
                default: break
            }
        }


        
        return self
    }

}
