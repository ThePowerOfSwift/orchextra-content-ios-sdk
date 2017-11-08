//
//  ActionInteractor.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 11/10/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import Foundation

protocol ActionInteractorProtocol {
    
    /// Method to get an action asynchronously
    ///
    /// - Parameters:
    ///   - forcindDownload: Set to true if you want to force the download
    ///   - url: The url of the action
    ///   - completion: Block to return the action
    func action(forcingDownload force: Bool, with identifier: String, completion: @escaping (Action?, Error?) -> Void)
}

struct ActionInteractor: ActionInteractorProtocol {
	
    let contentDataManager: ContentDataManager
	
    func action(forcingDownload force: Bool, with identifier: String, completion: @escaping (Action?, Error?) -> Void) {
        self.contentDataManager.loadElement(forcingDownload: force, with: identifier) { result in
            switch result {
            case .success(let action):
                completion(action, nil)
            case .error(let error):
                // Check if error is because of the action is login-restricted
                if error._userInfo?["OCM_ERROR_MESSAGE"] as? String == "requiredAuth" {
                    OCM.shared.delegate?.contentRequiresUserAuthentication {
                        if Config.isLogged {
                            // Maybe the Orchextra login doesn't finish yet, so
                            // We save the pending action to perform when the login did finish
                            // If the user is already logged in, the action will be performed automatically
                            ActionScheduleManager.shared.registerAction(for: .login) {
                                self.action(forcingDownload: force, with: identifier, completion: completion)
                            }
                        }
                    }
                } else {
                    completion(nil, error)
                }
            }
        }
    }
}
