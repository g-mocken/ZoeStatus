//
//  ServiceConnection.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 02.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import Foundation
import UIKit

class ServiceConnection {

    var activationCode: String?
    var userName:String?
    var password:String?
    var vehicleIdentification:String?
    var token:String?
    var refresh_token:String?
    
    let baseURL = "https://www.services.renault-ze.com/api"
    
    
    func login (callback:@escaping(Bool)->Void) {
    
        struct Credentials: Codable {
            let username: String
            let password: String
        }
        
        let credentials = Credentials(username: userName!,
                          password: password!)
        guard let uploadData = try? JSONEncoder().encode(credentials) else {
            return
        }
        
//        print(String(data: uploadData, encoding: .utf8)!)
        print("Sending: "+String(decoding: uploadData, as: UTF8.self))

        let loginURL = baseURL + "/user/login"
        let url = URL(string: loginURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                print ("error: \(error)")
                return
            }
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                    print ("server error")
                    return
            }
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                print ("got data: \(dataString)")
                
          

                
                struct loginResult: Codable {
                    var token: String
                    var refresh_token: String
                    var user: User
                    struct User: Codable {
                        var id: String
                        var locale: String
                        var country: String
                        var timezone: String
                        var email: String
                        var first_name: String
                        var last_name: String
                        var phone_number: String
                        var vehicle_details: Vehicle_Details
                        struct Vehicle_Details: Codable {
                            var timezone: String
                            var VIN: String
                            var activation_code: String
                            var phone_number: String
                        }
                        var scopes:[String]
                        var active_account: String
                        var associated_vehicles:[Associated_Vehicles]
                        struct Associated_Vehicles: Codable {
                            var VIN: String
                            var activation_code: String
                            var user_id: String
                        }
                        var gdc_uid: String
                    }
                }
                
                do{
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(loginResult.self, from: data)
                    
                    /*
                    print("Number of vehicles: " + String(format: "%d", result.user.associated_vehicles.count))
                    var i=0
                    for vehicle in result.user.associated_vehicles{
                        print("\(i):"+vehicle.VIN)
                        i+=1;
                    }
                    */
                    
                    self.vehicleIdentification = result.user.vehicle_details.VIN
                    self.activationCode = result.user.vehicle_details.activation_code
                    self.refresh_token = result.refresh_token
                    self.token = result.token
                    DispatchQueue.main.async {
                        callback(true)
                    }

                    
                } catch {
                    print (error)
                }
                
                
                
                
                
            }
        }
        task.resume()
        
        
        
    }
    
    


    func batteryState (callback:@escaping (Bool, Bool, UInt8, Float, UInt64, String?, Int?)->()) {
        
        let batteryURL = baseURL + "/vehicle/" + vehicleIdentification! + "/battery"

        let tString = ""
        let uploadData = tString.data(using: String.Encoding.utf8)
        
        let url = URL(string: batteryURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                print ("error: \(error)")
                return
            }
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                    print ("server error")
                    return
            }
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                print ("got data: \(dataString)")
                
                
                
                struct batteryStatusAlways: Codable{
                    var charging: Bool
                    var plugged: Bool
                    var charge_level: UInt8
                    var remaining_range: Float
                    var last_update: UInt64 //TimeInterval
                }
                struct batteryStatusPlugged: Codable{
                    var charging: Bool
                    var plugged: Bool
                    var charge_level: UInt8
                    var remaining_range: Float
                    var last_update: UInt64 //TimeInterval
                    var charging_point: String
                }
                struct batteryStatusPluggedAndCharging: Codable{
                    var charging: Bool
                    var plugged: Bool
                    var charge_level: UInt8
                    var remaining_range: Float
                    var last_update: UInt64 //TimeInterval
                    var charging_point: String
                    var remaining_time: Int
                }
                /*
                 The remaining_range is in Kilometres.
                 The last_update is a Unix timestamp. The remaining_time is in minutes.
                 
                 The charging_point is available only when plugged is true.
                 The remaining_time is available only when charging is true.
                 */
                
                let decoder = JSONDecoder()
                if let resultAlways = try? decoder.decode(batteryStatusAlways.self, from: data){
                    if resultAlways.plugged {
                        if let resultPlugged = try? decoder.decode(batteryStatusPlugged.self, from: data){
                            if  resultPlugged.charging {
                                if let resultPluggedAndCharging = try? decoder.decode(batteryStatusPluggedAndCharging.self, from: data)
                                { // plugged and charging
                                    DispatchQueue.main.async {
                                        callback(resultPluggedAndCharging.charging,
                                                 resultPluggedAndCharging.plugged,
                                                 resultPluggedAndCharging.charge_level,
                                                 resultPluggedAndCharging.remaining_range,
                                                 resultPluggedAndCharging.last_update,
                                                 resultPluggedAndCharging.charging_point,
                                                 resultPluggedAndCharging.remaining_time)
                                    }
                                }
                            } else { // not charging
                                DispatchQueue.main.async {
                                    callback(resultPlugged.charging,
                                             resultPlugged.plugged,
                                             resultPlugged.charge_level,
                                             resultPlugged.remaining_range,
                                             resultPlugged.last_update,
                                             resultPlugged.charging_point,
                                             nil)
                                }
                            }
                        }
                    } else { // not plugged
                        DispatchQueue.main.async {
                            callback(resultAlways.charging,
                                     resultAlways.plugged,
                                     resultAlways.charge_level,
                                     resultAlways.remaining_range,
                                     resultAlways.last_update,
                                     nil,
                                     nil)                        }
                    }
                }
                    
                
                
                
                
                
                
            }
        }
        task.resume()
    }
    
}
