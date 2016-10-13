//
//  SessionInteractor.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 13/10/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import Foundation
import GIGLibrary


struct SessionInteractor {
	
	var session: Session
	let orchextra: OrchextraWrapper
	
	func hasSession() -> Bool {
		guard self.session.clientToken != nil && self.session.accessToken != nil else { return false }
		
		return true
	}
	
	mutating func sessionExpired() {
		self.session.clientToken = nil
		self.session.accessToken = nil
	}
	
	mutating func loadSession(completion: (Result<Bool, String>) -> Void) {
		self.loadKeyAndSecret()
		guard let apiKey = self.session.apiKey else { return completion(.error("No API key set. First start Orchextra")) }
		guard let apiSecret = self.session.apiSecret else { return completion(.error("No API Secret set. First start Orchextra")) }
		
		self.orchextra.startWith(apikey: apiKey, apiSecret: apiSecret) { result in
			switch result {
			case .success(let credentials):
				self.session.accessToken = credentials.accessToken
				self.session.clientToken = credentials.clientToken
				
			case .error:
				completion(.error("Could not load credentials...."))
			}
		}
	}
	
	
	// MARK: - Private Helpers
	
	private mutating func loadKeyAndSecret() {
		self.session.apiSecret = self.orchextra.loadApiSecret()
		self.session.apiKey = self.orchextra.loadApiKey()
	}
}
