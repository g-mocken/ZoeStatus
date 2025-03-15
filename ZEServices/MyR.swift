//
//  MyR.swift
//  MyR Services
//
//  Created by Dr. Guido Mocken on 30.01.20.
//  Copyright © 2020 Dr. Guido Mocken. All rights reserved.
//

import Foundation
import os



class MyR {
    struct ApiKeyResult: Codable {
        var servers: Servers
        struct Servers: Codable {
            var wiredProd: ServerAndKey
            var gigyaProd: ServerAndKey
            struct ServerAndKey: Codable {
                var target: String
                var apikey: String
            }
        }
    }
    
    struct SessionInfo: Codable {
        var sessionInfo: SessionInfo
        struct SessionInfo: Codable {
            var cookieValue: String
        }
    }
    
    
    struct AccountInfo: Codable {
        var data:Data
        struct Data: Codable {
            var personId: String
        }
    }
    
    struct TokenInfo: Codable {
          var id_token:String
    }
    
    
    struct KamereonAccountInfo: Codable {
        var accounts:[Accounts]
        struct Accounts: Codable {
            var accountId: String
        }
    }
    
    struct KamereonTokenInfo: Codable {
        var accessToken:String
        var refreshToken:String
        var idToken:String
    }

    struct VehiclesInfo: Codable {
        var vehicleLinks:[vehicles]
        struct vehicles: Codable {
            var vin: String
        }
    }
    
  
    enum Version {
        case v1
        case v2
        
        var string: String {
            switch self{
            case .v1:
                return "v1"
            case .v2:
                return "v2"
            }
        }
    }
    
    var username: String!
    var password: String!
    var version: Version
    var kamereon: String?
    var vehicle: Int
    
    init(username u:String, password p:String, version v:Version, kamereon k:String, vehicle vid:Int) {
        username = u
        password = p
        version = v
        kamereon = k
        vehicle = vid // index 0...4 for 1st...5th in GUI
    }
    
    struct Context{
        var apiKeysAndUrls: ApiKeyResult?
        var sessionInfo: SessionInfo?
        var accountInfo: AccountInfo?
        var tokenInfo: TokenInfo?
        var kamereonAccountInfo: KamereonAccountInfo?
        var kamereonTokenInfo: KamereonTokenInfo?
        var vehiclesInfo: VehiclesInfo?
    }
    var context = Context()
    
    let country = "DE" // GB"
    let language = "de_DE" //"en_GB" // note that API and Kamereon key differ for GB and DE! But both work.
    
    let serviceLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "MYR")

    
    func decodeToken(token:String) {
        os_log("Decoding token:", log: self.serviceLog, type: .debug)

        let indexFirstPeriod = token.firstIndex(of: ".") ?? token.startIndex
        let header = String(token[..<indexFirstPeriod]).fromBase64()
        // first part
        os_log("Header:  %{public}s:", log: self.serviceLog, type: .debug, header!)

        let indexSecondPeriod = token[token.index(after:indexFirstPeriod)...].firstIndex(of: ".") ?? token.endIndex
        if let payload = String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]).fromBase64(){ // second part
            os_log("Payload:  %{public}s:", log: self.serviceLog, type: .debug, payload)
        }
        // the third part is the signature of the JSON web token, and not decoded/validated here
    }
    
    
    func handleLoginProcess(onError errorCode:@escaping(_ errorMessage:String)->Void, onSuccess actionCode:@escaping(_ vin:String?, _ token:String?, _ context:Context)->Void) {
        
        // Fetch URLs and API keys from a fixed URL
        let endpointUrl = URL(string: "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_" + language + ".json")!
        let components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: nil) { (result:ApiKeyResult?) -> Void in
            //if result != nil {
            if result != nil {
                os_log("Successfully retrieved targets and api keys:\nKamereon: %{public}s, key=%{public}s\nGigya: %{public}s, key=%{public}s", log: self.serviceLog, type: .debug, result!.servers.wiredProd.target, result!.servers.wiredProd.apikey, result!.servers.gigyaProd.target, result!.servers.gigyaProd.apikey)
                self.context.apiKeysAndUrls = result // save for later use
            } else {
                self.context.apiKeysAndUrls = ApiKeyResult(servers: ApiKeyResult.Servers(wiredProd: ApiKeyResult.Servers.ServerAndKey(target: "https://api-wired-prod-1-euw1.wrd-aws.com", apikey: "oF09WnKqvBDcrQzcW1rJNpjIuy7KdGaB"), gigyaProd: ApiKeyResult.Servers.ServerAndKey(target: "https://accounts.eu1.gigya.com", apikey: "3_7PLksOyBRkHv126x5WhHb-5pqC1qFR8pQjxSeLB6nhAnPERTUlwnYoznHSxwX668")))
            }
            
            // override Kamereon if a key is specified in user preferences:
            if self.kamereon! != "" {
                os_log("Override Kamereon Key: %{public}s", log: self.serviceLog, type: .debug, self.kamereon!)
                self.context.apiKeysAndUrls!.servers.wiredProd.apikey = self.kamereon!
            }
            
            // Fetch session key from the previously learned URL using the retreived API key
            let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.login")!
            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
                URLQueryItem(name: "loginID", value: self.username),
                URLQueryItem(name: "password", value: self.password),
                URLQueryItem(name: "sessionExpiration",value: "900") // try to set it myself, so I know the value
                // see https://developers.gigya.com/display/GD/accounts.login+REST
            ]
            self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:SessionInfo?) -> Void in
                if result != nil {
                    os_log("Successfully retrieved session key, Cookie value: %{public}s", log: self.serviceLog, type: .debug,result!.sessionInfo.cookieValue)
                    
                    self.context.sessionInfo = result // save for later use.
                    // do not know how to decode the cookie.
                    
                    let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getAccountInfo")!
                    var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                    components.queryItems = [
                        /* old style */
                        URLQueryItem(name: "oauth_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                        /* new style */
                        URLQueryItem(name: "login_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                        URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey)
                    ]
                    
                    // Fetch person ID from the same URL using the retrieved session key
                    self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:AccountInfo?) -> Void in
                        if result != nil {
                            os_log("Successfully retrieved account info, person ID: %{public}s", log: self.serviceLog, type: .debug, result!.data.personId)
                            
                            self.context.accountInfo = result // save for later use
                            
                            let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getJWT")!
                            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                            components.queryItems = [
                                /* old style */
                                URLQueryItem(name: "oauth_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                                /* new style */
                                URLQueryItem(name: "login_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                                URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
                                /* other fields */
                                URLQueryItem(name: "fields", value: "data.personId,data.gigyaDataCenter"),
                                URLQueryItem(name: "expiration", value: "900")
                            ]
                            
                            // Fetch Gigya JWT token from the same URL using the retrieved session key
                            self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:TokenInfo?) -> Void in
                                if result != nil {
                                    os_log("Successfully retrieved Gigya JWT token", log: self.serviceLog, type: .debug)
                                    self.context.tokenInfo = result // save for later use
                                    self.decodeToken(token:result!.id_token) // "exp" fields contains timestamp 900s in the future
                                    
                                    let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/persons/"+self.context.accountInfo!.data.personId)!
                                    var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                    components.queryItems = [
                                        URLQueryItem(name: "country", value: self.country)
                                    ]
                                    let headers = [
                                        "x-gigya-id_token":self.context.tokenInfo!.id_token,
                                        "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                                    ]
                                    // Fetch Kamereon account ID from the person-id dependent URL using the retrieved Gigya JWT token
                                    self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:KamereonAccountInfo?) -> Void in
                                        if result != nil {
                                            os_log("Successfully retrieved Kamereon accounts, Account id 0: %{public}s", log: self.serviceLog, type: .debug, result!.accounts[0].accountId)
                                            
                                            self.context.kamereonAccountInfo = result // save for later use
                                            
                                            
                                            let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/token")!
                                            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                            components.queryItems = [
                                                URLQueryItem(name: "country", value: self.country)
                                            ]
                                            let headers = [
                                                "x-gigya-id_token":self.context.tokenInfo!.id_token,
                                                "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                                            ]
                                            // Fetch Kamereon accessToken from the account dependent URL using the retrieved Gigya JWT token
                                            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:KamereonTokenInfo?) -> Void in
                                                if result != nil {
                                                    os_log("Successfully retrieved Kamereon accessToken", log: self.serviceLog, type: .debug)
                                                    self.context.kamereonTokenInfo = result // save for later use
                                                    self.decodeToken(token:result!.accessToken) // "expires_in":3600000 = 1h ?
                                                    // not used, just investigating:
                                                    //                                                        print("refreshToken:")
                                                    //                                                        self.decodeToken(token: result!.refreshToken)
                                                    //                                                        print("idToken:")
                                                    //                                                        self.decodeToken(token: result!.idToken)
                                                    
                                                    let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                                                    var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                    components.queryItems = [
                                                        URLQueryItem(name: "country", value: self.country)
                                                    ]
                                                    let headers = [
                                                        "x-gigya-id_token": self.context.tokenInfo!.id_token,
                                                        "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey,
                                                        "x-kamereon-authorization": "Bearer " + self.context.kamereonTokenInfo!.accessToken
                                                    ]
                                                    // Fetch VIN using the retrieved access token
                                                    self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:VehiclesInfo?) -> Void in
                                                        if result != nil {
                                                            os_log("Successfully retrieved vehicles with Kamereon token, Number of vehicles in account: %{public}d", log: self.serviceLog, type: .debug, result!.vehicleLinks.count)
                                                            
                                                            if self.vehicle >= result!.vehicleLinks.count {
                                                                errorCode("VIN index not found.")
                                                            } else {
                                                                os_log("VIN[%{public}d]: %{public}s", log: self.serviceLog, type: .debug, self.vehicle, result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin)
                                                                
                                                                self.context.vehiclesInfo = result // save for later use
                                                                
                                                                // must explicitly pass results, because the actionCode closure would use older captured values otherwise
                                                                actionCode(result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin, self.context.tokenInfo!.id_token, self.context)
                                                            }
                                                        } else {
                                                            errorCode("Error retrieving vehicles with Kamereon token")
                                                        }
                                                    } // end of closure
                                                } else {
                                                    os_log("Could not retrieve Kamereon token - trying without anyway", log: self.serviceLog, type: .debug)
                                                    
                                                    let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                                                    var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                    components.queryItems = [
                                                        URLQueryItem(name: "country", value: self.country)
                                                    ]
                                                    let headers = [
                                                        "x-gigya-id_token": self.context.tokenInfo!.id_token,
                                                        "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                                                    ]
                                                    // Fetch VIN using the retrieved access token
                                                    self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:VehiclesInfo?) -> Void in
                                                        if result != nil {
                                                            os_log("Successfully retrieved vehicles without Kamereon token, Number of vehicles in account: %{public}d", log: self.serviceLog, type: .debug, result!.vehicleLinks.count)
                                                            
                                                            if self.vehicle >= result!.vehicleLinks.count {
                                                                errorCode("VIN index not found.")
                                                            } else {
                                                                os_log("VIN[%{public}d]: %{public}s", log: self.serviceLog, type: .debug, self.vehicle, result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin)
                                                                
                                                                self.context.vehiclesInfo = result // save for later use
                                                                
                                                                // must explicitly pass results, because the actionCode closure would use older captured values otherwise
                                                                actionCode(result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin, self.context.tokenInfo!.id_token, self.context)
                                                            }
                                                        } else {
                                                            errorCode("Error retrieving vehicles without Kamereon token")
                                                        }
                                                    } // end of closure
                                                }
                                            } // end of closure
                                        } else {
                                            errorCode("Error retrieving Kamereon accounts")
                                        }
                                    } // end of closure
                                } else {
                                    errorCode("Error retrieving Gigya JWT token")
                                }
                            } // end of closure
                        } else {
                            errorCode("Error retrieving account info")
                        }
                    } // end of closure
                } else {
                    errorCode("Error retrieving session key")
                }
            } // end of closure
            //} else {
            //  errorCode("Error retrieving targets and api keys")
            //}
        } // end of closure
    }
    
    
    
    func handleLoginProcessAsync(onError errorCode:@escaping(_ errorMessage:String)->Void) async -> (vin:String?, token:String?, context:Context)  {
        
        // Fetch URLs and API keys from a fixed URL
        let endpointUrl1 = URL(string: "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_" + language + ".json")!
        let components1 = URLComponents(url: endpointUrl1, resolvingAgainstBaseURL: false)!
        let result1:ApiKeyResult? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components1, withHeaders: nil)
        //if result != nil {
        if result1 != nil {
            os_log("Successfully retrieved targets and api keys:\nKamereon: %{public}s, key=%{public}s\nGigya: %{public}s, key=%{public}s", log: self.serviceLog, type: .debug, result1!.servers.wiredProd.target, result1!.servers.wiredProd.apikey, result1!.servers.gigyaProd.target, result1!.servers.gigyaProd.apikey)
            self.context.apiKeysAndUrls = result1 // save for later use
        } else {
            self.context.apiKeysAndUrls = ApiKeyResult(servers: ApiKeyResult.Servers(wiredProd: ApiKeyResult.Servers.ServerAndKey(target: "https://api-wired-prod-1-euw1.wrd-aws.com", apikey: "oF09WnKqvBDcrQzcW1rJNpjIuy7KdGaB"), gigyaProd: ApiKeyResult.Servers.ServerAndKey(target: "https://accounts.eu1.gigya.com", apikey: "3_7PLksOyBRkHv126x5WhHb-5pqC1qFR8pQjxSeLB6nhAnPERTUlwnYoznHSxwX668")))
        }
        
        // override Kamereon if a key is specified in user preferences:
        if self.kamereon! != "" {
            os_log("Override Kamereon Key: %{public}s", log: self.serviceLog, type: .debug, self.kamereon!)
            self.context.apiKeysAndUrls!.servers.wiredProd.apikey = self.kamereon!
        }
        
        // Fetch session key from the previously learned URL using the retreived API key
        let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.login")!
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
            URLQueryItem(name: "loginID", value: self.username),
            URLQueryItem(name: "password", value: self.password),
            URLQueryItem(name: "sessionExpiration",value: "900") // try to set it myself, so I know the value
            // see https://developers.gigya.com/display/GD/accounts.login+REST
        ]
        let result:SessionInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .POST, withComponents: components, withHeaders: nil)
        if result != nil {
            os_log("Successfully retrieved session key, Cookie value: %{public}s", log: self.serviceLog, type: .debug,result!.sessionInfo.cookieValue)
            
            self.context.sessionInfo = result // save for later use.
            // do not know how to decode the cookie.
            
            let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getAccountInfo")!
            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                /* old style */
                URLQueryItem(name: "oauth_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                /* new style */
                URLQueryItem(name: "login_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey)
            ]
            
            // Fetch person ID from the same URL using the retrieved session key
            let result:AccountInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .POST, withComponents: components, withHeaders: nil)
            if result != nil {
                os_log("Successfully retrieved account info, person ID: %{public}s", log: self.serviceLog, type: .debug, result!.data.personId)
                
                self.context.accountInfo = result // save for later use
                
                let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getJWT")!
                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    /* old style */
                    URLQueryItem(name: "oauth_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                    /* new style */
                    URLQueryItem(name: "login_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                    URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
                    /* other fields */
                    URLQueryItem(name: "fields", value: "data.personId,data.gigyaDataCenter"),
                    URLQueryItem(name: "expiration", value: "900")
                ]
                
                // Fetch Gigya JWT token from the same URL using the retrieved session key
                let result:TokenInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .POST, withComponents: components, withHeaders: nil)
                if result != nil {
                    os_log("Successfully retrieved Gigya JWT token", log: self.serviceLog, type: .debug)
                    self.context.tokenInfo = result // save for later use
                    self.decodeToken(token:result!.id_token) // "exp" fields contains timestamp 900s in the future
                    
                    let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/persons/"+self.context.accountInfo!.data.personId)!
                    var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                    components.queryItems = [
                        URLQueryItem(name: "country", value: self.country)
                    ]
                    let headers = [
                        "x-gigya-id_token":self.context.tokenInfo!.id_token,
                        "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                    ]
                    // Fetch Kamereon account ID from the person-id dependent URL using the retrieved Gigya JWT token
                    let result:KamereonAccountInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
                    if result != nil {
                        os_log("Successfully retrieved Kamereon accounts, Account id 0: %{public}s", log: self.serviceLog, type: .debug, result!.accounts[0].accountId)
                        
                        self.context.kamereonAccountInfo = result // save for later use
                        
                        
                        let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/token")!
                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                        components.queryItems = [
                            URLQueryItem(name: "country", value: self.country)
                        ]
                        let headers = [
                            "x-gigya-id_token":self.context.tokenInfo!.id_token,
                            "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                        ]
                        // Fetch Kamereon accessToken from the account dependent URL using the retrieved Gigya JWT token
                        let result:KamereonTokenInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
                        if result != nil {
                            os_log("Successfully retrieved Kamereon accessToken", log: self.serviceLog, type: .debug)
                            self.context.kamereonTokenInfo = result // save for later use
                            self.decodeToken(token:result!.accessToken) // "expires_in":3600000 = 1h ?
                            // not used, just investigating:
                            //                                                        print("refreshToken:")
                            //                                                        self.decodeToken(token: result!.refreshToken)
                            //                                                        print("idToken:")
                            //                                                        self.decodeToken(token: result!.idToken)
                            
                            let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                            components.queryItems = [
                                URLQueryItem(name: "country", value: self.country)
                            ]
                            let headers = [
                                "x-gigya-id_token": self.context.tokenInfo!.id_token,
                                "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey,
                                "x-kamereon-authorization": "Bearer " + self.context.kamereonTokenInfo!.accessToken
                            ]
                            // Fetch VIN using the retrieved access token
                            let  result:VehiclesInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
                            if result != nil {
                                os_log("Successfully retrieved vehicles with Kamereon token, Number of vehicles in account: %{public}d", log: self.serviceLog, type: .debug, result!.vehicleLinks.count)
                                
                                if self.vehicle >= result!.vehicleLinks.count {
                                    errorCode("VIN index not found.")
                                } else {
                                    os_log("VIN[%{public}d]: %{public}s", log: self.serviceLog, type: .debug, self.vehicle, result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin)
                                    
                                    self.context.vehiclesInfo = result // save for later use
                                    
                                    // must explicitly pass results, because the actionCode closure would use older captured values otherwise
                                    return (vin: result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin, token: self.context.tokenInfo!.id_token, context: self.context)
                                }
                            } else {
                                errorCode("Error retrieving vehicles with Kamereon token")
                            }
                        } else {
                            os_log("Could not retrieve Kamereon token - trying without anyway", log: self.serviceLog, type: .debug)
                            
                            let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                            components.queryItems = [
                                URLQueryItem(name: "country", value: self.country)
                            ]
                            let headers = [
                                "x-gigya-id_token": self.context.tokenInfo!.id_token,
                                "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                            ]
                            // Fetch VIN using the retrieved access token
                            let result:VehiclesInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
                            if result != nil {
                                os_log("Successfully retrieved vehicles without Kamereon token, Number of vehicles in account: %{public}d", log: self.serviceLog, type: .debug, result!.vehicleLinks.count)
                                
                                if self.vehicle >= result!.vehicleLinks.count {
                                    errorCode("VIN index not found.")
                                } else {
                                    os_log("VIN[%{public}d]: %{public}s", log: self.serviceLog, type: .debug, self.vehicle, result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin)
                                    
                                    self.context.vehiclesInfo = result // save for later use
                                    
                                    // must explicitly pass results, because the actionCode closure would use older captured values otherwise
                                    return (vin: result!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin, token: self.context.tokenInfo!.id_token, context: self.context)
                                }
                            } else {
                                errorCode("Error retrieving vehicles without Kamereon token")
                            }
                        }
                    } else {
                        errorCode("Error retrieving Kamereon accounts")
                    }
                } else {
                    errorCode("Error retrieving Gigya JWT token")
                }
            } else {
                errorCode("Error retrieving account info")
            }
        } else {
            errorCode("Error retrieving session key")
        }
        //} else {
        //  errorCode("Error retrieving targets and api keys")
        //}
        return (nil,nil, context) // indicates error on return error this way!
    }
    
    func getHeaders()->[String:String] {
        if context.kamereonTokenInfo != nil {
            return [
                "x-gigya-id_token": context.tokenInfo!.id_token,
                "apikey": context.apiKeysAndUrls!.servers.wiredProd.apikey,
                "x-kamereon-authorization": "Bearer " + context.kamereonTokenInfo!.accessToken,
                "Content-Type": "application/vnd.api+json"
            ]
        } else {
            return [
                "x-gigya-id_token": context.tokenInfo!.id_token,
                "apikey": context.apiKeysAndUrls!.servers.wiredProd.apikey,
                "Content-Type": "application/vnd.api+json"
            ]
        }
 
    }
    
    func batteryState(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?, Int?, String?) -> ()) {
        
        let version: Version = .v2
        
        struct BatteryInfoV2: Codable {
            var data: Data
            struct Data: Codable {
                var type: String?
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var batteryLevel: Int?
                    var batteryTemperature: Int?
                    var chargingInstantaneousPower: Float?
                    var batteryAutonomy: Float?
                    var chargingRemainingTime: Int?
                    var plugStatus: Int
                    var timestamp: String
                    var chargingStatus: Float
                    var batteryCapacity: Int?
                    var batteryAvailableEnergy: Int?
                }
            }
        }
        
        /*
            not plugged, not charging:
         {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T19:06:03+01:00","batteryLevel":63,"batteryTemperature":9,"batteryAutonomy":71,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":0,"chargingStatus":-1.0}}}
         
        
        plugged and charging:
         {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T21:17:35+01:00","batteryLevel":62,"batteryTemperature":9,"batteryAutonomy":70,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":1,"chargingStatus":1.0}}}
         
         2020-02-07 21:22:04.731187+0100 ZoeStatus[43997:3264106] [ZOE-MYR] raw JSON data: {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T21:21:26+01:00","batteryLevel":63,"batteryTemperature":9,"batteryAutonomy":71,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":1,"chargingStatus":1.0,"chargingRemainingTime":300,"chargingInstantaneousPower":2300.0}}}

         
         
         With errors:
         
         raw JSON data: {"data":{"id":"...","attributes":{"timestamp":"2024-05-31T15:59:12Z","batteryAutonomy":108,"plugStatus":0,"chargingStatus":-1.1}}}

         
         */
        
        struct BatteryInfo: Codable {
            var data: Data
            struct Data: Codable {
                var type: String?
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var batteryLevel: Int?
                    var batteryTemperature: Int?
                    var chargePower: Int?
                    var rangeHvacOff: Float?
                    var timeRequiredToFullSlow: Int?
                    var plugStatus: Int
                    var instantaneousPower: Int?
                    var lastUpdateTime: String
                    var chargeStatus: Int
                }
            }
        }
        /*
         Sample Data while slow charging:
         {
         "data":{
         "type":"Car",
         "id":"...",
         "attributes":{
         "batteryLevel":79,
         "batteryTemperature":11,
         "chargePower":1,
         "rangeHvacOff":98,
         "timeRequiredToFullSlow":175,
         "plugStatus":1,
         "instantaneousPower":2200,
         "lastUpdateTime":"2020-01-29T20:14:28+01:00",
         "chargeStatus":1
         }
         }
         }
         
         Sample Data while NOT charging:
         
         {"data":{"type":"Car","id":"...",
         "attributes":{
         "batteryTemperature":14,
         "chargeStatus":-1,
         "batteryLevel":59,
         "rangeHvacOff":78,
         "lastUpdateTime":"2020-01-31T17:39:52+01:00",
         "plugStatus":0}}
         }
         
         
         
         Sample data while plugged, but NOT charging:
         {"data":{"type":"Car","id":"...", "attributes":{"chargeStatus":-1,"batteryTemperature":16,"lastUpdateTime":"2020-02-03T23:24:54+01:00","plugStatus":1,"rangeHvacOff":106,"batteryLevel":81}}}
         
         Sometimes some required fields are missing:
         {"data":{"type":"Car","id":"...",
         "attributes":{"batteryTemperature":16,"chargeStatus":-1,"lastUpdateTime":"2020-02-05T23:54:19+01:00","plugStatus":0}}}
         
         
         */
        // print ("\(context.apiKeysAndUrls!)")
        // print ("\(context.vehiclesInfo!)")
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + version.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/battery-status")!
                
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        // Fetch info using the retrieved access token
        
        switch version {
        case .v1:
            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:BatteryInfo?) -> Void in
                if result != nil {
                    os_log("Successfully retrieved battery state V1:\n level: %d\n battery temperature: %d", log: self.serviceLog, type: .debug, result!.data.attributes.batteryLevel ?? "N/A", result!.data.attributes.batteryTemperature ?? "N/A")

                    var charging_point: String?
                    if let power=result!.data.attributes.chargePower {
                        switch power {
                        case 0:
                            charging_point = "INVALID"
                        case 1:
                            charging_point = "SLOW"
                        case 2:
                            charging_point = "FAST"
                        case 3:
                            charging_point = "ACCELERATED"
                        default:
                            charging_point = "\(power)"
                        }
                    }

                    // overwrite the above with power in kW if it is present
                    if let power=result!.data.attributes.instantaneousPower {
                        charging_point = "\(Float(power)/1000.0) kW"
                    }
                    
                    
                    let dateString = result!.data.attributes.lastUpdateTime // e.g. "2020-01-31T17:39:52+01:00"
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    let date = dateFormatter.date(from:dateString)!
                    let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                    // print(date)
                    
                    // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                    DispatchQueue.main.async{
                        callback(false,
                                 result!.data.attributes.chargeStatus > 0,
                                 result!.data.attributes.plugStatus > 0,
                                 UInt8(result!.data.attributes.batteryLevel ?? 0),
                                 result!.data.attributes.rangeHvacOff ?? -1.0,
                                 unixMs,
                                 charging_point,
                                 result!.data.attributes.timeRequiredToFullSlow,
                                 result!.data.attributes.batteryTemperature,
                                 result!.data.id)
                        
                    }
                } else {
                    
                    os_log("Error retrieving battery state V1", log: self.serviceLog, type: .debug)

                    DispatchQueue.main.async{
                        callback(true,
                                 false,
                                 false,
                                 0,
                                 0.0,
                                 0,
                                 nil,
                                 nil,
                                 nil,
                                 nil)
                    }
                }
            }
            
        case .v2:
            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:BatteryInfoV2?) -> Void in
                if result != nil {
                    os_log("Successfully retrieved battery state V2:\n level: %d\n battery temperature: %d", log: self.serviceLog, type: .debug, result!.data.attributes.batteryLevel ?? -128, result!.data.attributes.batteryTemperature ?? -128)

                    var charging_point: String?
                    if let power=result!.data.attributes.chargingInstantaneousPower {
                        switch power {
                        case -10...0:
                            charging_point = "INVALID"
/*
                        case 0.1..<11000.0:
                            charging_point = "SLOW"
                        case 11000.0..<22000.0:
                            charging_point = "FAST"
                        case 22000.0..<100000.0:
                            charging_point = "ACCELERATED"
*/
                        default:
                            charging_point = "\(power/1000.0) kW"
                        }
                    }
                    
                    let dateString = result!.data.attributes.timestamp // e.g. "2020-01-31T17:39:52+01:00"
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    let date = dateFormatter.date(from:dateString)!
                    let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                    //print(date)
                    
                    // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                    DispatchQueue.main.async{
                        callback(false,
                                 result!.data.attributes.chargingStatus == 1.0 || (result!.data.attributes.chargingRemainingTime ?? 0 > 0       ) /* see https://github.com/hacf-fr/renault-api/blob/main/src/renault_api/kamereon/enums.py */,
                                 result!.data.attributes.plugStatus > 0,
                                 UInt8(result!.data.attributes.batteryLevel ?? 0),
                                 result!.data.attributes.batteryAutonomy ?? -1.0,
                                 unixMs,
                                 charging_point,
                                 result!.data.attributes.chargingRemainingTime,
                                 result!.data.attributes.batteryTemperature,
                                 result!.data.id)
                        
                    }
                } else {
                    
                    os_log("Error retrieving battery state V2", log: self.serviceLog, type: .debug)

                    DispatchQueue.main.async{
                        callback(true,
                                 false,
                                 false,
                                 0,
                                 0.0,
                                 0,
                                 nil,
                                 nil,
                                 nil,
                                 nil)
                    }
                }
            }
        }
    }
    
    func batteryStateAsync() async -> (error:Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?, battery_temperature:Int?, vehicle_id:String?) {
        
        let version: Version = .v2
        
        struct BatteryInfoV2: Codable {
            var data: Data
            struct Data: Codable {
                var type: String?
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var batteryLevel: Int?
                    var batteryTemperature: Int?
                    var chargingInstantaneousPower: Float?
                    var batteryAutonomy: Float?
                    var chargingRemainingTime: Int?
                    var plugStatus: Int
                    var timestamp: String
                    var chargingStatus: Float
                    var batteryCapacity: Int?
                    var batteryAvailableEnergy: Int?
                }
            }
        }
        
        /*
         not plugged, not charging:
         {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T19:06:03+01:00","batteryLevel":63,"batteryTemperature":9,"batteryAutonomy":71,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":0,"chargingStatus":-1.0}}}
         
         
         plugged and charging:
         {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T21:17:35+01:00","batteryLevel":62,"batteryTemperature":9,"batteryAutonomy":70,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":1,"chargingStatus":1.0}}}
         
         2020-02-07 21:22:04.731187+0100 ZoeStatus[43997:3264106] [ZOE-MYR] raw JSON data: {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T21:21:26+01:00","batteryLevel":63,"batteryTemperature":9,"batteryAutonomy":71,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":1,"chargingStatus":1.0,"chargingRemainingTime":300,"chargingInstantaneousPower":2300.0}}}
         
         
         
         With errors:
         
         raw JSON data: {"data":{"id":"...","attributes":{"timestamp":"2024-05-31T15:59:12Z","batteryAutonomy":108,"plugStatus":0,"chargingStatus":-1.1}}}
         
         
         */
        
        struct BatteryInfo: Codable {
            var data: Data
            struct Data: Codable {
                var type: String?
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var batteryLevel: Int?
                    var batteryTemperature: Int?
                    var chargePower: Int?
                    var rangeHvacOff: Float?
                    var timeRequiredToFullSlow: Int?
                    var plugStatus: Int
                    var instantaneousPower: Int?
                    var lastUpdateTime: String
                    var chargeStatus: Int
                }
            }
        }
        /*
         Sample Data while slow charging:
         {
         "data":{
         "type":"Car",
         "id":"...",
         "attributes":{
         "batteryLevel":79,
         "batteryTemperature":11,
         "chargePower":1,
         "rangeHvacOff":98,
         "timeRequiredToFullSlow":175,
         "plugStatus":1,
         "instantaneousPower":2200,
         "lastUpdateTime":"2020-01-29T20:14:28+01:00",
         "chargeStatus":1
         }
         }
         }
         
         Sample Data while NOT charging:
         
         {"data":{"type":"Car","id":"...",
         "attributes":{
         "batteryTemperature":14,
         "chargeStatus":-1,
         "batteryLevel":59,
         "rangeHvacOff":78,
         "lastUpdateTime":"2020-01-31T17:39:52+01:00",
         "plugStatus":0}}
         }
         
         
         
         Sample data while plugged, but NOT charging:
         {"data":{"type":"Car","id":"...", "attributes":{"chargeStatus":-1,"batteryTemperature":16,"lastUpdateTime":"2020-02-03T23:24:54+01:00","plugStatus":1,"rangeHvacOff":106,"batteryLevel":81}}}
         
         Sometimes some required fields are missing:
         {"data":{"type":"Car","id":"...",
         "attributes":{"batteryTemperature":16,"chargeStatus":-1,"lastUpdateTime":"2020-02-05T23:54:19+01:00","plugStatus":0}}}
         
         
         */
        // print ("\(context.apiKeysAndUrls!)")
        // print ("\(context.vehiclesInfo!)")
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + version.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/battery-status")!
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()
        
        // Fetch info using the retrieved access token
        
        switch version {
        case .v1:
            let result:BatteryInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
            if result != nil {
                os_log("Successfully retrieved battery state V1:\n level: %d\n battery temperature: %d", log: self.serviceLog, type: .debug, result!.data.attributes.batteryLevel ?? "N/A", result!.data.attributes.batteryTemperature ?? "N/A")
                
                var charging_point: String?
                if let power=result!.data.attributes.chargePower {
                    switch power {
                    case 0:
                        charging_point = "INVALID"
                    case 1:
                        charging_point = "SLOW"
                    case 2:
                        charging_point = "FAST"
                    case 3:
                        charging_point = "ACCELERATED"
                    default:
                        charging_point = "\(power)"
                    }
                }
                
                // overwrite the above with power in kW if it is present
                if let power=result!.data.attributes.instantaneousPower {
                    charging_point = "\(Float(power)/1000.0) kW"
                }
                
                
                let dateString = result!.data.attributes.lastUpdateTime // e.g. "2020-01-31T17:39:52+01:00"
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = NSLocale.current
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                let date = dateFormatter.date(from:dateString)!
                let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                // print(date)
                
                // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                return (false,
                        result!.data.attributes.chargeStatus > 0,
                        result!.data.attributes.plugStatus > 0,
                        UInt8(result!.data.attributes.batteryLevel ?? 0),
                        result!.data.attributes.rangeHvacOff ?? -1.0,
                        unixMs,
                        charging_point,
                        result!.data.attributes.timeRequiredToFullSlow,
                        result!.data.attributes.batteryTemperature,
                        result!.data.id)
            } else {
                
                os_log("Error retrieving battery state V1", log: self.serviceLog, type: .debug)
                return (true,
                        false,
                        false,
                        0,
                        0.0,
                        0,
                        nil,
                        nil,
                        nil,
                        nil)
            }
            
            
        case .v2:
            let result:BatteryInfoV2? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
            if result != nil {
                os_log("Successfully retrieved battery state V2:\n level: %d\n battery temperature: %d", log: self.serviceLog, type: .debug, result!.data.attributes.batteryLevel ?? -128, result!.data.attributes.batteryTemperature ?? -128)
                
                var charging_point: String?
                if let power=result!.data.attributes.chargingInstantaneousPower {
                    switch power {
                    case -10...0:
                        charging_point = "INVALID"
                        /*
                         case 0.1..<11000.0:
                         charging_point = "SLOW"
                         case 11000.0..<22000.0:
                         charging_point = "FAST"
                         case 22000.0..<100000.0:
                         charging_point = "ACCELERATED"
                         */
                    default:
                        charging_point = "\(power/1000.0) kW"
                    }
                }
                
                let dateString = result!.data.attributes.timestamp // e.g. "2020-01-31T17:39:52+01:00"
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = NSLocale.current
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                let date = dateFormatter.date(from:dateString)!
                let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                //print(date)
                
                // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                
                return (false,
                        result!.data.attributes.chargingStatus == 1.0 || (result!.data.attributes.chargingRemainingTime ?? 0 > 0       ) /* see https://github.com/hacf-fr/renault-api/blob/main/src/renault_api/kamereon/enums.py */,
                        result!.data.attributes.plugStatus > 0,
                        UInt8(result!.data.attributes.batteryLevel ?? 0),
                        result!.data.attributes.batteryAutonomy ?? -1.0,
                        unixMs,
                        charging_point,
                        result!.data.attributes.chargingRemainingTime,
                        result!.data.attributes.batteryTemperature,
                        result!.data.id)
            } else {
                
                os_log("Error retrieving battery state V2", log: self.serviceLog, type: .debug)
                
                return (true,
                        false,
                        false,
                        0,
                        0.0,
                        0,
                        nil,
                        nil,
                        nil,
                        nil)
            }
        }
    }
        
    func cockpitState(callback:@escaping  (Bool, Float?) -> ()) {
        
        let version:Version = .v1
        /*
         
        v1:
        Request: https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1/accounts/xxxx/kamereon/kca/car-adapter/v1/cars/V.../cockpit?country=DE
        {"data":{"type":"Car","id":"V...","attributes":{"totalMileage":55842}}}

         
        v2:
        Request: https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1/accounts/xxxx/kamereon/kca/car-adapter/v2/cars/V.../cockpit?country=DE
        {"data":{"type":"Car","id":"V...","attributes":{"totalMileage":55842.21}}}

         */
        
        struct cockpitInfoV1: Codable {
                    var data: Data
                    struct Data: Codable {
                        var type: String?
                        var id: String
                        var attributes: Attributes
                        struct Attributes: Codable {
                            var totalMileage: Int
                        }
                    }
                }
        
        struct cockpitInfoV2: Codable {
                var data: Data
                struct Data: Codable {
                    var type: String?
                    var id: String
                    var attributes: Attributes
                    struct Attributes: Codable {
                        var totalMileage: Float
                    }
                }
            }
        
            let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + version.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/cockpit")!
                    
            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "country", value: self.country)
            ]
            let headers = getHeaders()

            // Fetch info using the retrieved access token
            
            switch version {
            case .v1:
                self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:cockpitInfoV1?) -> Void in
                    if result != nil {
                        os_log("Successfully retrieved cockpit state V1:\n total mileage: %d km", log: self.serviceLog, type: .debug, result!.data.attributes.totalMileage)

                        DispatchQueue.main.async{
                            callback(false, Float(result!.data.attributes.totalMileage))
                        }
                    } else {
                        DispatchQueue.main.async{
                            callback(true, nil)
                        }
                    }
                }
                
            case .v2:
                self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:cockpitInfoV2?) -> Void in
                    if result != nil {
                        os_log("Successfully retrieved cockpit state V2:\n total mileage: %d km", log: self.serviceLog, type: .debug, result!.data.attributes.totalMileage)

                        DispatchQueue.main.async{
                            callback(false, result!.data.attributes.totalMileage)
                            
                        }
                    } else {
                        DispatchQueue.main.async{
                            callback(true, nil)
                        }
                    }
                }
            }
        }
    
    
    
    func cockpitStateAsync() async -> (error:Bool, total_mileage:Float?){
        
        
        let version:Version = .v1
        /*
         
         v1:
         Request: https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1/accounts/xxxx/kamereon/kca/car-adapter/v1/cars/V.../cockpit?country=DE
         {"data":{"type":"Car","id":"V...","attributes":{"totalMileage":55842}}}
         
         
         v2:
         Request: https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1/accounts/xxxx/kamereon/kca/car-adapter/v2/cars/V.../cockpit?country=DE
         {"data":{"type":"Car","id":"V...","attributes":{"totalMileage":55842.21}}}
         
         */
        
        struct cockpitInfoV1: Codable {
            var data: Data
            struct Data: Codable {
                var type: String?
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var totalMileage: Int
                }
            }
        }
        
        struct cockpitInfoV2: Codable {
            var data: Data
            struct Data: Codable {
                var type: String?
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var totalMileage: Float
                }
            }
        }
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + version.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/cockpit")!
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()
        
        // Fetch info using the retrieved access token
        
        switch version {
        case .v1:
            let result:cockpitInfoV1? = await fetchJsonDataViaHttpAsync(usingMethod:.GET, withComponents: components, withHeaders: headers)
            
            if result != nil {
                os_log("Successfully retrieved cockpit state V1:\n total mileage: %d km", log: self.serviceLog, type: .debug, result!.data.attributes.totalMileage)
                return (error: false, total_mileage: Float(result!.data.attributes.totalMileage))
            } else {
                return (error: true, total_mileage: nil)
            }
            
        case .v2:
            let result:cockpitInfoV2? = await fetchJsonDataViaHttpAsync(usingMethod:.GET, withComponents: components, withHeaders: headers)
            if result != nil {
                os_log("Successfully retrieved cockpit state V2:\n total mileage: %d km", log: self.serviceLog, type: .debug, result!.data.attributes.totalMileage)
                return (error: false, total_mileage: result!.data.attributes.totalMileage)
            } else {
                return (error: true, total_mileage: nil)
            }
        }
    }
    
    public func chargeNowRequest(callback:@escaping  (Bool) -> ()) {
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/actions/charging-start")!

        
        struct StartCharging: Codable {
            var data: Data
            struct Data:Codable {
                var type: String
                var id: String?
                var attributes:Attributes
                struct Attributes:Codable {
                    var action:String
                }
            }
        }
           
        let startCharging = StartCharging(data: StartCharging.Data(type: "ChargingStart", attributes: StartCharging.Data.Attributes(action: "start")))
        
        guard let uploadData = try? JSONEncoder().encode(startCharging) else {
            callback(false)
            return
        }
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()
                 
        // Fetch info using the retrieved access token
        self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: headers, withBody: uploadData) { (result:    StartCharging?) -> Void in
            if result != nil {
                // print("Successfully sent request, got: \(result!.data)")
                DispatchQueue.main.async{
                    callback(false)
                }
            } else {
                DispatchQueue.main.async{
                    callback(true)
                }
            }
        }
    }
    
    public func chargeNowRequestAsync() async -> (Bool) {
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/actions/charging-start")!

        
        struct StartCharging: Codable {
            var data: Data
            struct Data:Codable {
                var type: String
                var id: String?
                var attributes:Attributes
                struct Attributes:Codable {
                    var action:String
                }
            }
        }
           
        let startCharging = StartCharging(data: StartCharging.Data(type: "ChargingStart", attributes: StartCharging.Data.Attributes(action: "start")))
        
        guard let uploadData = try? JSONEncoder().encode(startCharging) else {
            return (false)
        }
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()
                 
        // Fetch info using the retrieved access token
        let result:StartCharging? = await fetchJsonDataViaHttpAsync(usingMethod: .POST, withComponents: components, withHeaders: headers, withBody: uploadData)
        if result != nil {
            // print("Successfully sent request, got: \(result!.data)")
            return (false)
        } else {
            return (true)
        }
        
    }

    
    
    /*
     
     'actions/hvac-start',
     {
        'type': 'HvacStart',
        'attributes‘:{
                'action': 'start' / ‚cancel’
                'targetTemperature': temperature
                'startDateTime‘: "%Y-%m-%dT%H:%M:%SZ"
        }
      }
     
     */
    
    /**
     
        date picker + save :
     preconditionCar(command: .later, date: preconditionRemoteTimer)
        date picker + trash button:
     preconditionCar(command: .delete, date: nil)
        AC now (also shortcut from 3d touch):
     preconditionCar(command: .now, date: nil)
     
        refresh status:
     sc.precondition(command: .read, date: nil, callback: self.preconditionState)


     */
    public func precondition(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?, Float?) -> ()) {
        
        let endpointUrl:URL
        
        switch command {
        case .read:
            endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/hvac-status")!  // endpoint does no longer exist? error 404 -> missing time for next planned session and missing external temperature

        case .now, .later, .delete:
            endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/actions/hvac-start")!
        }
        
        
        struct PreconditionInfo: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var hvacStatus: String
                    var externalTemperature: Float
                    var nextHvacStartDate: String?
                }
            }
        }
        
        struct Precondition: Codable {
            var data: Data
            struct Data:Codable {
                var type: String
                var id: String?
                var attributes:Attributes?
                struct Attributes:Codable {
                    var action: String
                    var targetTemperature: Float?
                    var startDateTime: String?
                }
            }
        }
        
        let precondition:Precondition?
        
        switch command {
        case .now:
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "start", targetTemperature: 21.0)))

        case .later:
            
            // combine time received with today's date:
            let today = Date()
            let finalDate:Date
            if (date!<today){
                // if in the past, add one day
                finalDate = date! + TimeInterval(24*3600)
            } else {
                finalDate = date!
            }
            // date now is the correct time and date.

            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let strDate = dateFormatter.string(from: finalDate)
            
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "start", targetTemperature: 21.0, startDateTime: strDate)))
        case .delete:
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "cancel")))
        case .read:
            precondition = nil
        }
        
        let uploadData:Data?
        
        if (precondition == nil){ // for .read
            uploadData = nil
        } else {
            uploadData = try? JSONEncoder().encode(precondition)
            if (uploadData == nil) {
                callback(false, command, date, nil)
                return
            } else {
                // print(String(data: uploadData!, encoding: .utf8)!)
            }
        }
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        if (command == .read) { // for .read GET status
            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers, withBody: uploadData) { (result:PreconditionInfo?) -> Void in
                if result != nil {
                    //print("Successfully sent GET request, got: \(result!.data)")
                    //print("External temperature: \(result!.data.attributes.externalTemperature)")
                    let date:Date?
                    if let dateString = result!.data.attributes.nextHvacStartDate {
                        // e.g. "2020-02-03T06:30:00Z"
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = NSLocale.current
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                        date = dateFormatter.date(from:dateString)!
                    } else {
                        date = nil
                    }
                    DispatchQueue.main.async{
                        callback(false, command, date, result!.data.attributes.externalTemperature)
                    }
                } else {
                    DispatchQueue.main.async{
                        callback(true, command, date, nil)
                    }
                }
            }
        } else { // all other commands POST action
            self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: headers, withBody: uploadData) { (result:Precondition?) -> Void in
                if result != nil {
                    // print("Successfully sent POST request, got: \(result!.data)")
                    DispatchQueue.main.async{
                        callback(false, command, date, nil)
                    }
                } else {
                    DispatchQueue.main.async{
                        callback(true, command, date, nil)
                    }
                }
            }
        }
    }
    
    
    public func preconditionAsync(command:PreconditionCommand, date: Date?) async -> (error: Bool, command:PreconditionCommand, date: Date?, externalTemperature: Float? ) {
        
        let endpointUrl:URL
        
        switch command {
        case .read:
            endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/hvac-status")!  // endpoint does no longer exist? error 404 -> missing time for next planned session and missing external temperature

        case .now, .later, .delete:
            endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/actions/hvac-start")!
        }
        
        
        struct PreconditionInfo: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var hvacStatus: String
                    var externalTemperature: Float
                    var nextHvacStartDate: String?
                }
            }
        }
        
        struct Precondition: Codable {
            var data: Data
            struct Data:Codable {
                var type: String
                var id: String?
                var attributes:Attributes?
                struct Attributes:Codable {
                    var action: String
                    var targetTemperature: Float?
                    var startDateTime: String?
                }
            }
        }
        
        let precondition:Precondition?
        
        switch command {
        case .now:
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "start", targetTemperature: 21.0)))

        case .later:
            
            // combine time received with today's date:
            let today = Date()
            let finalDate:Date
            if (date!<today){
                // if in the past, add one day
                finalDate = date! + TimeInterval(24*3600)
            } else {
                finalDate = date!
            }
            // date now is the correct time and date.

            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let strDate = dateFormatter.string(from: finalDate)
            
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "start", targetTemperature: 21.0, startDateTime: strDate)))
        case .delete:
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "cancel")))
        case .read:
            precondition = nil
        }
        
        let uploadData:Data?
        
        if (precondition == nil){ // for .read
            uploadData = nil
        } else {
            uploadData = try? JSONEncoder().encode(precondition)
            if (uploadData == nil) {
                return (false, command, date, nil)
            } else {
                // print(String(data: uploadData!, encoding: .utf8)!)
            }
        }
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        if (command == .read) { // for .read GET status
            let result:PreconditionInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers, withBody: uploadData)
            if result != nil {
                    //print("Successfully sent GET request, got: \(result!.data)")
                    //print("External temperature: \(result!.data.attributes.externalTemperature)")
                    let date:Date?
                    if let dateString = result!.data.attributes.nextHvacStartDate {
                        // e.g. "2020-02-03T06:30:00Z"
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = NSLocale.current
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                        date = dateFormatter.date(from:dateString)!
                    } else {
                        date = nil
                    }
                return (error: false, command: command, date: date, externalTemperature: result!.data.attributes.externalTemperature)
                } else {
                    return (error: true, command: command, date: date, externalTemperature: nil)
                }
        } else { // all other commands POST action
            let result:PreconditionInfo? = await fetchJsonDataViaHttpAsync(usingMethod: .POST, withComponents: components, withHeaders: headers, withBody: uploadData)
                if result != nil {
                    // print("Successfully sent POST request, got: \(result!.data)")
                    return (error: false, command: command, date: date, externalTemperature: nil)
                } else {
                    return (error: true, command: command, date: date, externalTemperature: nil)
                }
        }
    }
    

    
    public func airConditioningLastState(callback:@escaping  (Bool, UInt64, String?, String?) -> ()) {
        
        struct HvacSessions: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var hvacSessions: [HvacSession]
                    struct HvacSession: Codable {
                        var hvacSessionRequestDate: String
                        var hvacSessionStartDate: String
                        var hvacSessionEndStatus: String
                    }
                }
            }
        }
        /*
         {"data":{"type":"Car","id":"...","attributes":{"hvacSessions":[{"hvacSessionRequestDate":"2020-02-03T17:20:05+01:00","hvacSessionStartDate":"2020-02-03T17:26:38+01:00","hvacSessionEndStatus":"ok"},{"hvacSessionRequestDate":"2020-02-03T00:30:48+01:00","hvacSessionStartDate":"2020-02-03T07:29:42+01:00","hvacSessionEndStatus":"error"},{"hvacSessionRequestDate":"2020-02-02T16:25:59+01:00","hvacSessionStartDate":"2020-02-02T16:32:32+01:00","hvacSessionEndStatus":"error"}]}}}
         
         */
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/hvac-sessions")! // endpoint does no longer exist? error 404 -> missing status&time&date of last session
        
        let dateFormatter = DateFormatter()
        let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
        dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyyMMdd"
        let startDate = dateFormatter.string(from: Date()-24*3600*7) // go back one week
        let endDate = dateFormatter.string(from: Date()) // today
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start", value: startDate),
            URLQueryItem(name: "end", value: endDate),
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        // Fetch info using the retrieved access token
        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:HvacSessions?) -> Void in
            if result != nil {
                os_log("Successfully retrieved AC sessions: %d sessions", log: self.serviceLog, type: .debug, result!.data.attributes.hvacSessions.count)

                if (result!.data.attributes.hvacSessions.count > 0) { // array not empty  - never happens, HTTP 500 instead!
                    os_log("AC last state:\n hvacSessionRequestDate: %{public}s\n hvacSessionStartDate: %{public}s\n hvacSessionEndStatus: %{public}s", log: self.serviceLog, type: .debug, result!.data.attributes.hvacSessions[0].hvacSessionRequestDate, result!.data.attributes.hvacSessions[0].hvacSessionStartDate, result!.data.attributes.hvacSessions[0].hvacSessionEndStatus)

                    let dateString = result!.data.attributes.hvacSessions[0].hvacSessionStartDate
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    let date = dateFormatter.date(from:dateString)!
                    let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                    
                    let status = result!.data.attributes.hvacSessions[0].hvacSessionEndStatus
                    
                    let rStatus:String?
                    switch status {
                    case "error":
                        rStatus = "ERROR"
                    case "ok":
                        rStatus = "SUCCESS"
                    default:
                        rStatus = nil
                    }
                    
                    //print("A/C last state: \(date), \(rStatus ?? "-")")
                    
                    DispatchQueue.main.async {
                        callback(false,
                                 unixMs,
                                 "USER_REQUEST",
                                 rStatus)
                    }
                    
                } else { // array empty, no data
                    DispatchQueue.main.async {
                        callback(false, // no error, but no data
                                 0,
                                 nil,
                                 nil)
                    }
                }
                
            
            } else {
                DispatchQueue.main.async {
                    callback(false, // true = error getting data -> dialog
                             0,
                             nil,
                             nil)
                }
            }
        }
    }
    
    
    public func airConditioningLastStateAsync() async -> (error: Bool, date:UInt64, type:String?, result:String?){
        
        struct HvacSessions: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var hvacSessions: [HvacSession]
                    struct HvacSession: Codable {
                        var hvacSessionRequestDate: String
                        var hvacSessionStartDate: String
                        var hvacSessionEndStatus: String
                    }
                }
            }
        }
        /*
         {"data":{"type":"Car","id":"...","attributes":{"hvacSessions":[{"hvacSessionRequestDate":"2020-02-03T17:20:05+01:00","hvacSessionStartDate":"2020-02-03T17:26:38+01:00","hvacSessionEndStatus":"ok"},{"hvacSessionRequestDate":"2020-02-03T00:30:48+01:00","hvacSessionStartDate":"2020-02-03T07:29:42+01:00","hvacSessionEndStatus":"error"},{"hvacSessionRequestDate":"2020-02-02T16:25:59+01:00","hvacSessionStartDate":"2020-02-02T16:32:32+01:00","hvacSessionEndStatus":"error"}]}}}
         
         */
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks.sorted(by: { $0.vin < $1.vin })[self.vehicle].vin + "/hvac-sessions")! // endpoint does no longer exist? error 404 -> missing status&time&date of last session
        
        let dateFormatter = DateFormatter()
        let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
        dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyyMMdd"
        let startDate = dateFormatter.string(from: Date()-24*3600*7) // go back one week
        let endDate = dateFormatter.string(from: Date()) // today
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start", value: startDate),
            URLQueryItem(name: "end", value: endDate),
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()
        
        // Fetch info using the retrieved access token
        let result:HvacSessions? = await fetchJsonDataViaHttpAsync(usingMethod: .GET, withComponents: components, withHeaders: headers)
        if result != nil {
            os_log("Successfully retrieved AC sessions: %d sessions", log: self.serviceLog, type: .debug, result!.data.attributes.hvacSessions.count)
            
            if (result!.data.attributes.hvacSessions.count > 0) { // array not empty  - never happens, HTTP 500 instead!
                os_log("AC last state:\n hvacSessionRequestDate: %{public}s\n hvacSessionStartDate: %{public}s\n hvacSessionEndStatus: %{public}s", log: self.serviceLog, type: .debug, result!.data.attributes.hvacSessions[0].hvacSessionRequestDate, result!.data.attributes.hvacSessions[0].hvacSessionStartDate, result!.data.attributes.hvacSessions[0].hvacSessionEndStatus)
                
                let dateString = result!.data.attributes.hvacSessions[0].hvacSessionStartDate
                let dateFormatter = DateFormatter()
                dateFormatter.locale = NSLocale.current
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                let date = dateFormatter.date(from:dateString)!
                let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                
                let status = result!.data.attributes.hvacSessions[0].hvacSessionEndStatus
                
                let rStatus:String?
                switch status {
                case "error":
                    rStatus = "ERROR"
                case "ok":
                    rStatus = "SUCCESS"
                default:
                    rStatus = nil
                }
                
                //print("A/C last state: \(date), \(rStatus ?? "-")")
                
                return (error:false,
                        date:unixMs,
                        type:"USER_REQUEST",
                        result:rStatus)
                
            } else { // array empty, no data
                return (error:false, // no error, but no data
                        date:0,
                        type:nil,
                        result:nil)
            }
            
            
        } else {
            return (error:false, // true = error getting data -> dialog
                    date:0,
                    type:nil,
                    result:nil)
        }
        
    }

    
    
    enum HttpMethod {
        case GET
        case POST
        case PUT
        
        var string: String { // computed property
            switch self {
            case .GET:
                return "GET"
            case .PUT:
                return "PUT"
               case .POST:
                return "POST"
               }
           }
    }
    
    func fetchJsonDataViaHttp<T> (usingMethod method:HttpMethod, withComponents components:URLComponents, withHeaders headers:[String:String]?, withBody body: Data?=nil, callback:@escaping(T?)->Void) where T:Decodable {
    
        let query = components.url!.query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.string
        if (query != nil) && (method == .POST) {
            request.httpBody = Data(query!.utf8) // must not be used for GET
        }
        
        if (body != nil) && (method == .POST) {
            request.httpBody = body
        }
        
        request.allHTTPHeaderFields = headers
        // request.setValue("...", forHTTPHeaderField: "...")

//        os_log("MYR default log mesage.", log: serviceLog, type: .default)
//        os_log("MYR debug log mesage.", log: serviceLog, type: .debug)
//        os_log("MYR info log mesage.", log: serviceLog, type: .info)
//        os_log("MYR error log mesage.", log: serviceLog, type: .error)

        
        let task = URLSession.shared.dataTask(with: request){ data, response, error in
            
            os_log("Request: %{public}s", log: self.serviceLog, type: .debug, request.description)
            if (request.httpBody != nil) {os_log("POST-Body: %{public}s", log: self.serviceLog, type: .debug, String(data: request.httpBody!, encoding: .utf8)!)
            }
            if let error = error {
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                callback(nil)
                return
            }
            
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    callback(nil)
                    return
            }
            
            if let jsonData = data {
                os_log("raw JSON data: %{public}s", log: self.serviceLog, type: .debug, String(data: jsonData, encoding: .utf8)!)

                let decoder = JSONDecoder()
                let result = try? decoder.decode(T.self, from: jsonData)
                callback(result)
            } else {
                callback(nil)
            }
        } // task completion handler end
        
        task.resume()
        
    }
    
    
    // variant which uses async URLSession.shared.data() function jut as is because it is async itself (i.e. must be called from Task), simply returns result and has no callback for that
    func fetchJsonDataViaHttpAsync<T> (usingMethod method:HttpMethod, withComponents components:URLComponents, withHeaders headers:[String:String]?, withBody body: Data?=nil) async -> T? where T:Decodable {
        
        let query = components.url!.query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.string
        if (query != nil) && (method == .POST) {
            request.httpBody = Data(query!.utf8) // must not be used for GET
        }

        if (body != nil) && (method == .POST) {
            request.httpBody = body
        }
        request.allHTTPHeaderFields = headers
        // request.setValue("...", forHTTPHeaderField: "...")

        
        // Perform the network request using async/await
        do {

            let (jsonData, response) = try await URLSession.shared.data(for: request)

            os_log("Request: %{public}s", log: self.serviceLog, type: .debug, request.description)

            if (request.httpBody != nil) {os_log("POST-Body: %{public}s", log: self.serviceLog, type: .debug, String(data: request.httpBody!, encoding: .utf8)!)
            }

            guard let resp = response as? HTTPURLResponse,
                  (200...299).contains(resp.statusCode)
                    
            else {
                os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                return nil
            }
            
            os_log("raw JSON data: %{public}s", log: self.serviceLog, type: .debug, String(data: jsonData, encoding: .utf8)!)
            let decoder = JSONDecoder()
            let result = try? decoder.decode(T.self, from: jsonData)
            return result
            
        } catch {
            // Handle errors
            os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
            return nil
            
            
        }
    }

    // Wrapper for async variant which is a 1:1 replacement for fetchJsonDataViaHttp<>() (for testing the async variant only)
    func fetchJsonDataViaHttpAsyncWrapper<T> (usingMethod method:HttpMethod, withComponents components:URLComponents, withHeaders headers:[String:String]?, withBody body: Data?=nil, callback:@escaping(T?)->Void) where T:Decodable {
        Task {
            let result:T? = await fetchJsonDataViaHttpAsync(usingMethod:method, withComponents: components, withHeaders: headers, withBody: body)
            callback(result)
        }
    }

    

}
