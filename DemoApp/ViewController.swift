//
//  ViewController.swift
//  DemoApp
//
//  Created by Alejandro Jiménez Agudo on 30/3/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import UIKit
import OCMSDK
import GIGLibrary
import Orchextra

class ViewController: UIViewController {

    let ocm = OCM.shared
    var menu: [Section] = []
    let session = Session.shared
    var searchViewController: OCMSDK.SearchVC?
    let appController = AppController.shared
    
    @IBOutlet weak var sectionsMenu: SectionsMenu!
    @IBOutlet weak var pagesContainer: PagesContainerScroll!
    @IBOutlet weak var logoOrx: UIImageView!
    @IBOutlet weak var labelOrx: UILabel!
    @IBOutlet weak var splashOrx: UIView!
    

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.ocm.contentDelegate = self
        self.ocm.federatedAuthenticationDelegate = self
        self.ocm.schemeDelegate = self
        self.ocm.customBehaviourDelegate = self
        self.ocm.eventDelegate = self
        switch InfoDictionary("OCM_HOST") {
        case "staging":
            self.ocm.environment = .staging
        case "quality":
            self.ocm.environment = .quality
        case "production":
            self.ocm.environment = .production
        default:
            self.ocm.environment = .staging
        }
        self.ocm.logLevel = .debug
        self.ocm.logStyle = .funny
        self.ocm.videoEventDelegate = self
        self.ocm.parameterCustomizationDelegate = self
        self.ocm.thumbnailEnabled = false
        self.ocm.customBehaviourDelegate = self
        self.ocm.contentViewDelegate = self
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            self.ocm.backgroundSessionCompletionHandler = appDelegate.backgroundSessionCompletionHandler
        }
        self.localize()
        self.customize()
        self.addProviders()
        self.ocm.paginationConfig = PaginationConfig(items: 7)
//        self.ocm.offlineSupportConfig = OfflineSupportConfig(cacheSectionLimit: 10, cacheElementsPerSectionLimit: 6, cacheFirstSectionLimit: 12)
        self.startOrchextra()
        
        self.perform(#selector(hideSplashOrx), with: self, afterDelay: 1.0)
    }
    
    // MARK: - IBActions
    
    @IBAction func settingsTapped(_ sender: Any) {
        
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.appController.settings()
    }
    
    // MARK: - Setup
    
    func startOrchextra() {
        self.ocm.start(
            apiKey: self.appController.orchextraApiKey,
            apiSecret: self.appController.orchextraApiSecret) { result in
                switch result {
                case .success:
                    self.session.saveORX(
                        apikey: self.appController.orchextraApiKey,
                        apisecret: self.appController.orchextraApiSecret
                    )
                    let businessUnit = InfoDictionary("OCM_BUSINESS_UNIT")
                    self.ocm.enableOrchextraModules([.proximity])
                    if !businessUnit.isEmpty {
                        self.ocm.set(businessUnits: [businessUnit], completion: {
                            self.ocm.loadMenus()
                        })
                    } else {
                        self.ocm.loadMenus()
                    }
                case .error:
                    self.showCredentialsErrorMessage()
                }
        }
    }
    
    func restartOrx() {
        if let credentials = self.session.loadORXCredentials() {
            self.appController.orchextraApiKey = credentials.apikey
            self.appController.orchextraApiSecret = credentials.apisecret
        }
        self.startOrchextra()
        
    }

    func showCredentialsErrorMessage() {
        let alert = Alert(
            title: "Credentials are not correct",
            message: "Apikey and Apisecret are invalid")
        alert.addCancelButton("Ok") { _ in
            self.restartOrx()
        }
        alert.show()
    }
    
    func addProviders() {
        let providers = Providers()
        providers.vimeo = VimeoProvider(accessToken: "34e1438469ab50e311a171463c8e4f62")
        self.ocm.providers = providers
    }
    
    func localize() {
        let strings = Strings(
            appName: "DemoApp",
            contentError: "There was an error obtaining content",
            unexpectedError: "Uh oh! Something went wrong",
            noResultsForSearch: "There are no results for your search",
            internetConnectionRequired: "Please check your Internet connection",
            passbookErrorUnsupportedVersion: "Your device does not support this version of Passbook",
            okButton: "OK",
            orxAcceptButtonTitle: "OK",
            orxCancelButtonTitle: "Cancel",
            orxSettingsButtonTitle: "Settings",
            orxBackgroundLocationAlertMessage: "The application needs the location in background to provide personalized content based in your position. Please visit your device settings to enable location permissions 'Always'",
            orxScannerTitle: "Scanner",
            orxScannerMessage: "Scanning...",
            orxCameraPermissionDeniedTitle: "Camera use not allowed",
            orxCameraPermissionDeniedMessage: "You have not permission to use device camera. You must to enable it from 'Settings'"
        )
        self.ocm.strings = strings
    }
    
    func customize() {
        let styles = Styles()
        styles.primaryColor = UIColor(fromHexString: "#EB0853")
        styles.placeholderImage = #imageLiteral(resourceName: "thumbnail")
        styles.primaryColor = .darkGray
        self.ocm.styles = styles
        
        let navigationBarStyles = ContentNavigationBarStyles()
        let navigationBarView = BackgroundColorHour(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 80))
        navigationBarView.tonality = .dark
        let navigationBarImage = navigationBarView.convertToImage()
        navigationBarStyles.type = .navigationBar
        navigationBarStyles.barBackgroundImage = navigationBarImage
        navigationBarStyles.backButtonImage = #imageLiteral(resourceName: "white_back_arrow")
        navigationBarStyles.showTitle = true
        self.ocm.contentNavigationBarStyles = navigationBarStyles
        
        let contentListStyles = ContentListStyles()
        contentListStyles.transitionBackgroundImage = #imageLiteral(resourceName: "color")
        contentListStyles.placeholderImage = #imageLiteral(resourceName: "thumbnailGridTransparent")
        self.ocm.contentListStyles = contentListStyles
        
        let contentListCarouselStyles = ContentListCarouselLayoutStyles()
        contentListCarouselStyles.pageControlOffset = -30
        contentListCarouselStyles.inactivePageIndicatorColor = .gray
        contentListCarouselStyles.autoPlay = true
        
        let articleStyles = ArticleStyles()
        articleStyles.richtextFont = UIFont(name: "RoundedMplus-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        articleStyles.richtextColor = UIColor(fromHexString: "#296fc1")
        articleStyles.headerFont = UIFont(name: "RoundedMplus-Bold", size: 22) ?? UIFont.systemFont(ofSize: 22)
        articleStyles.headerTextColor = UIColor(fromHexString: "#296fc1")
        let backgroundViewFactory = BackgroundViewFactoryImpl()
        articleStyles.backgroundView = backgroundViewFactory
        self.ocm.articleStyles = articleStyles
        
        self.ocm.contentListCarouselLayoutStyles = contentListCarouselStyles
        self.pagesContainer.delegate = self
    }
    
    @objc func hideSplashOrx() {
        UIView.animate(withDuration: 0.5) {
            self.splashOrx.alpha = 0
        }
    }

    // MARK: - Private methods
    
    fileprivate func showSection(atPage page: Int) {
        guard page < self.menu.count else { return }
        let currentSection = self.menu[page]
        
        currentSection.openAction { action in
            if let action = action {
                self.pagesContainer.show(action, atIndex: page)
            }
        }
    }
    
    fileprivate func shouldLoadNextPage() -> Bool {
        let pageOffset = self.pagesContainer.contentOffset.x / self.pagesContainer.frame.size.width
        return pageOffset == round(pageOffset)
    }
    
    func showPassbook(error: PassbookError) {
        var message: String = ""
        switch error {
        case .error:
            message = "Lo sentimos, ha ocurrido un error inesperado"
        case .unsupportedVersionError:
            message = "Su dispositivo no es compatible con passbook"
        }
        
        let actionSheetController: UIAlertController = UIAlertController(title: "Title", message: message, preferredStyle: .alert)
        let cancelAction: UIAlertAction = UIAlertAction(title: "Ok", style: .default) { _ -> Void in
        }
        actionSheetController.addAction(cancelAction)
        self.present(actionSheetController, animated: true, completion: nil)
    }
    
    func show(section index: Int) {
        self.sectionsMenu.navigate(toSectionIndex: index)
    }
}

extension ViewController: ContentDelegate {
    
    func userDidOpenContent(with identifier: String) {
        print("Did open content \(identifier)")
    }
    
    func menusDidRefresh(_ menus: [Menu]) {
        guard let menu = menus.filter({ $0.sections.count != 0 }).first else { return }
        if self.menu != menu.sections {
            self.menu = menu.sections
            self.sectionsMenu.load(sections: menu.sections, contentScroll: self.pagesContainer)
            self.pagesContainer.prepare(forNumberOfPages: menu.sections.count, viewController: self)
            self.showSection(atPage: 0)
        }
    }
}

extension ViewController: FederatedAuthenticationDelegate {
    
    func federatedAuthentication(_ federated: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        logInfo("Needs federated authentication")
        completion(["sso_token": "U2FsdGVkX1+zsyT1ULUqZZoAd/AANGnkQExYsAnzFlY5/Ff/BCkaSSuhR0/xvy0e"])
    }
}

extension ViewController: URLSchemeDelegate {
    
    func openURLScheme(_ url: URLComponents) {
        print("CUSTOM SCHEME: \(url)")
        UIApplication.shared.openURL(url.url!)
    }
}

extension ViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.sectionsMenu.contentScrollViewDidEndDecelerating()
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.sectionsMenu.contentScrollViewWillEndDragging()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.presentedViewController != nil { logWarn("presentedViewController is nil"); return }
        self.sectionsMenu.contentDidScroll(to: scrollView.frame.origin.x)
        let appearingPage = Int(ceil((scrollView.contentOffset.x) / scrollView.frame.size.width))
        
        guard appearingPage < self.menu.count else { logWarn("menu is nil"); return }
        self.showSection(atPage: appearingPage)
        
        if self.shouldLoadNextPage() {
            self.showSection(atPage: appearingPage + 1)
        }
    }
}

extension ViewController: EventDelegate {
    
    func contentPreviewDidLoad(identifier: String, type: String) {
        logInfo("identifier: \(identifier), type: \(type)")
    }
    
    func contentDidLoad(identifier: String, type: String) {
        logInfo("identifier: \(identifier), type: \(type)")
    }
    
    func userDidShareContent(identifier: String, type: String) {
        logInfo("identifier: \(identifier), type: \(type)")
    }
    
    func userDidOpenContent(identifier: String, type: String) {
        logInfo("identifier: \(identifier), type: \(type)")
    }
    
    func videoDidLoad(identifier: String) {
        logInfo("identifier: \(identifier)")
    }
    
    func sectionDidLoad(_ section: Section) {
        logInfo("loaded section: \(section.name)")
    }
}

extension ViewController: CustomBehaviourDelegate {
    
    func contentNeedsValidation(for customProperties: [String: Any], completion: @escaping (Bool) -> Void) {
        if let requiredAuth = customProperties["requiredAuth"] as? String, requiredAuth == "logged" {
            OCM.shared.didLogin(with: "1234") {
                completion(true)
            }
        } else {
            completion(true)
        }
    }
    
    func contentNeedsCustomization(_ content: CustomizableContent, completion: @escaping (CustomizableContent) -> Void) {
        if content.viewType == .gridContent {
            if let requiredAuth = content.customProperties["requiredAuth"] as? String, requiredAuth == "logged" {
                content.customizations.append(.viewLayer(BlockedView.instantiate()))
                completion(content)
            }
        } else if content.viewType == .buttonElement {
            content.customizations.append(.disabled)
            completion(content)
        } else {
            completion(content)
        }
    }
}

extension ViewController: ParameterCustomizationDelegate {
    
    func actionNeedsValues(for parameters: [String]) -> [String: String?] {
        return [
            "promo-id": "673",
            "value": "ocm"
        ]
    }
}

extension ViewController: OCMSDK.VideoEventDelegate {
    
    func videoDidStart(identifier: String) {
        print("Video Start: " + identifier)
    }
    
    func videoDidStop(identifier: String) {
        print("Video Stop: " + identifier)
    }
    
    func videoDidPause(identifier: String) {
        print("Video Pause: " + identifier)
    }
}

extension ViewController: ContentViewDelegate {
    
    func errorView(error: String, reloadBlock: @escaping () -> Void) -> UIView? {
        let backgroundImage = UIImage(named: "rectangle8")
        let errorView = ErrorViewDefault()
        errorView.backgroundImage = backgroundImage
        errorView.title = "Ups!"
        errorView.subtitle = "Nous avons une erreur"
        errorView.buttonTitle = "RECOMMENCEZ"
        errorView.set(retryBlock: {
            reloadBlock()
        })
        return errorView.instantiate()
    }
    
    func loadingView() -> UIView? {
        let backgroundImage = UIImage(named: "rectangle8")
        let loadingView = LoadingViewDefault()
        loadingView.title = "Chargement"
        loadingView.backgroundImage = backgroundImage
        return loadingView.instantiate()
    }
    
    func noContentView() -> UIView? {
        let backgroundImage = UIImage(named: "rectangle8")
        let noContentView = NoContentViewDefault()
        noContentView.backgroundImage = backgroundImage
        noContentView.title = "Pardon!"
        noContentView.subtitle = "Il n'a pas de jet de contenu"
        return noContentView.instantiate()
    }
    
    func noResultsForSearchView() -> UIView? {
        return nil
    }

    func newContentsAvailableView() -> UIView? {
        return NewContentView.instantiate()
    }
}

func delay(_ delay: Double, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure
    )
}
