//
//  OCM.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 30/3/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import UIKit
import GIGLibrary
/**
The OCM class provides you with methods for starting the framework and retrieve the ViewControllers to use within your app.


### Usage

You should use the `shared` property to get a unique singleton instance, then set your `logLevel`


### Overview

Once the framework is started, you can retrive the ViewControllers to show the content list


- Since: 1.0
- Version: 1.0
- Author: Alejandro Jiménez Agudo
- Copyright: Gigigo S.L.
*/
public class OCM {
	
	public static let shared = OCM()
	
	/**
	Type of OCM's logs you want displayed in the debug console
	
	- **none**: No log will be shown. Recommended for production environments.
	- **error**: Only warnings and errors. Recommended for develop environments.
	- **info**: Errors and relevant information. Recommended for testing OCM integration.
	- **debug**: Request and Responses to OCM's server will be displayed. Not recommended to use, only for debugging OCM.
	*/
	public var logLevel: LogLevel {
		didSet {
			LogManager.shared.logLevel = self.logLevel
		}
	}
	
	public var delegate: OCMDelegate?
	public var analytics: OCMAnalytics?
	
	
	public var host: String {
		didSet {
			Config.Host = self.host
		}
	}
	
	public var countryCode: String {
		didSet {
			Config.CountryCode = self.countryCode
		}
	}
	
	public var appVersion: String {
		didSet {
			Config.AppVersion = self.appVersion
		}
	}
	
	public var palette: Palette? {
		didSet {
			Config.Palette = self.palette
		}
	}
	
	public var placeholder: UIImage? {
		didSet {
			Config.placeholder = self.placeholder
		}
	}
	
	public var noContentImage: UIImage? {
		didSet {
			Config.noContentImage = self.noContentImage
		}
	}
	
	fileprivate let wireframe = Wireframe(
		application: Application()
	)
	
	
	init() {
		self.logLevel = .none
		LogManager.shared.appName = "OCM"
		self.host = ""
		self.countryCode = ""
		self.appVersion = ""
		self.placeholder = nil
	}
	
	/**
	Retrieve the section list
	
	Use it to build a dynamic menu in your app
	
	- returns: Dictionary of sections to be represented
	
	- Since: 1.0
	*/
	public func menus() -> [String: [Section]] {		
		return [ "slug-of-the-death": [
			Section(name: "All",				action: "/element/goContent/579a2ab2893ba7c1648b45d7"),
			Section(name: "Webview",			action: "/element/webview/579a2ab2893ba7c1648b1111"),
			Section(name: "Scan",				action: "/element/scan/579a2ab2893ba7c1648b2222"),
			Section(name: "Drinks Ranking",		action: "/element/article/579a2ab2893ba7c1648b3333"),
			Section(name: "Vaya tio",			action: "/element/deepLink/579a2ab2893ba7c1648b4444"),
			Section(name: "el Sergio López",	action: "/element/goContent/579a2ab2893ba7c1648b45d7")
			]
		]
	}
	
	
	/**
	Run the action from an url
	
	**Discussion:** It will be executed only if was previously loaded.
	
	Use it to run actions programatically (for example it can be triggered with an application url scheme)
	
	- parameter uri: The url that represent the action to run
	
	- Since: 1.0
	*/
	public func openAction(from uri: String) -> UIViewController? {
		return nil//self.wireframe.contentList(from: uri)
	}
	
	/**
	Retrieve the content list view controller
	
	Use it to present this view to your users
	
	- returns: ViewController to be presented
	
	- Since: 1.0
	*/
	public func notificationReceived(_ notification: [AnyHashable : Any]) {
		PushInteractor().pushReceived(notification)
	}
}

public protocol OCMDelegate {
	func openCoupons()
	func openCoupon(with id: String)
	func customScheme(_ url: URLComponents)
	func sessionExpired()
}

public protocol OCMAnalytics {
	func trackEvent(_ eventName: String)
}

