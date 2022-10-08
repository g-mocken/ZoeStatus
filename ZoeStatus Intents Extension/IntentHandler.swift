//
//  IntentHandler.swift
//  ZoeStatus Intents Extension
//
//  Created by Dr. Guido Mocken on 05.10.22.
//  Copyright © 2022 Dr. Guido Mocken. All rights reserved.
//

import Intents
import ZEServices

class IntentHandler: INExtension, INGetCarPowerLevelStatusIntentHandling {
    
    let sc=ServiceConnection.shared

    
    
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
                
                self.sc.batteryState(){
                error, charging, plugged, charge_level, remaining_range, last_update, charging_point, remaining_time, battery_temperature, vehicle_id in
                    
                    let response = INGetCarPowerLevelStatusIntentResponse(code: INGetCarPowerLevelStatusIntentResponseCode.success, userActivity: nil)
                    

                    response.charging = charging
                    response.chargePercentRemaining = Float(charge_level)/100.0 // 0.12 = 12%
                    response.distanceRemaining = Measurement(value: Double(remaining_range), unit: UnitLength.kilometers)
                    response.activeConnector =  INCar.ChargingConnectorType.mennekes
                    response.carIdentifier = vehicle_id
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
        
      
        
                
       

        
      
    }
    
//
//    override func handler(for intent: INIntent) -> Any {
//        // This is the default implementation.  If you want different objects to handle different intents,
//        // you can override this and return the handler you want for that particular intent.
//
//        print("handle \(intent)")
//        switch intent {
//            case is INGetCarPowerLevelStatusIntent: return self
//            default: break
//        }
//
//
//        return self
//    }
//
}
