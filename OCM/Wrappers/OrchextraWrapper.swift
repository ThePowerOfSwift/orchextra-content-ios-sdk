//
//  OrchextraWrapper.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 13/10/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//
import Foundation
import GIGLibrary
import Orchextra


typealias Credentials = (clientToken: String, accessToken: String)


struct OrchextraWrapper {
	
	let orchextra: Orchextra = Orchextra.sharedInstance()
	let config = ORCSettingsDataManager()
	
	func loadApiKey() -> String? {
		self.checkOrchextra()
		return self.config.apiKey()
	}
	
	func loadApiSecret() -> String? {
		self.checkOrchextra()
		return self.config.apiSecret()
	}
	
	func startWith(apikey: String, apiSecret: String, completion: @escaping (Result<(clientToken: String, accessToken: String), Error>) -> Void) {
		self.orchextra.setApiKey(apikey, apiSecret: apiSecret) { success, error in
			if success {
				let credentials: Credentials = (
					clientToken: self.config.clientToken(),
					accessToken: self.config.accessToken()
				)
				
				completion(.success(credentials))
			} else {
				//				completion(.error(error as? NSError))
			}
		}
		
	}
    
    
    func startScanner() {
        self.orchextra.startScanner()
    }
	
	
	private func checkOrchextra() {
		if !self.config.isOrchextraRunning() {
			LogInfo("Orchextra is not running! You must set the api key and api secret first.")
		}
	}
}
