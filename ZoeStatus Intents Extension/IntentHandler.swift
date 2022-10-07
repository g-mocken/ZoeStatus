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
    
    
    func resolveCarName(for intent: INGetCarPowerLevelStatusIntent, with completion: @escaping (INSpeakableStringResolutionResult) -> Void) {
        print("resolving... \(intent)")
        print("Car name: \(String(describing: intent.carName)) ")

        
        let result: INSpeakableStringResolutionResult

//          if let carName = intent.carName {
//              result = INSpeakableStringResolutionResult.success(with: carName)
//          }
//          else {
//              result = INSpeakableStringResolutionResult.needsValue()
//          }
        result = INSpeakableStringResolutionResult.success(with: INSpeakableString(spokenPhrase: "Renault Zoë"))
        completion(result)


    }
    
    func confirm(intent: INGetCarPowerLevelStatusIntent, completion: @escaping (INGetCarPowerLevelStatusIntentResponse) -> Void) {
        print("confirming... \(intent)")
        
        let response = INGetCarPowerLevelStatusIntentResponse(code: .ready, userActivity: nil)
        

        completion(response)
    }

    let sc=ServiceConnection.shared

    func handle(intent: INGetCarPowerLevelStatusIntent, completion: @escaping (INGetCarPowerLevelStatusIntentResponse) -> Void) {
        
        print("handling... \(intent)")

        print("Car name: \(String(describing: intent.carName)) ")
        
        
        let response = INGetCarPowerLevelStatusIntentResponse(code: INGetCarPowerLevelStatusIntentResponseCode.success, userActivity: nil)
        
        
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.synchronize()
        let userName = sharedDefaults?.string(forKey:"userName")
        let password = sharedDefaults?.string(forKey:"password")
        let api = sharedDefaults?.integer(forKey: "api")
        let units = sharedDefaults?.integer(forKey: "units")
        let kamereon = sharedDefaults?.string(forKey: "kamereon")
        let vehicle = sharedDefaults?.integer(forKey: "vehicle")

        sc.userName = userName
        sc.password = password
        sc.api = ServiceConnection.ApiVersion(rawValue: api!)
        sc.units = ServiceConnection.Units(rawValue: units!)
        sc.kamereon = kamereon
        sc.vehicle = vehicle
        
        if sc.userName == "simulation", sc.password == "simulation"
        {
            sc.simulation = true
        } else {
            sc.simulation = false
        }

        sc.login(){(result:Bool, errorMessage:String?)->() in
            if result {
                print("Login to Z.E. / MY.R. services successful")
                
                self.sc.batteryState(){
                error, charging, plugged, charge_level, remaining_range, last_update, charging_point, remaining_time, battery_temperature, vehicle_id in
                    
                    
                    
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
