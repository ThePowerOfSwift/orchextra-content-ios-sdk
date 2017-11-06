//
//  Wireframe.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 30/3/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import UIKit
import GIGLibrary
import SafariServices


class Wireframe: NSObject, WebVCDismissable {
	
	let application: Application

    init(application: Application) {
        self.application = application
    }
	
	func contentList(from path: String? = nil) -> OrchextraViewController {
		guard let contentListVC = try? ContentListVC.instantiateFromStoryboard() else {
			logWarn("Couldn't instantiate ContentListVC")
			return OrchextraViewController()
		}
		
		contentListVC.presenter = ContentListPresenter(
			view: contentListVC,
			contentListInteractor: ContentListInteractor(
                contentDataManager: .sharedDataManager
			),
            sectionInteractor: SectionInteractor(
                contentDataManager: .sharedDataManager
            ),
            ocm: OCM.shared,
            actionScheduleManager: ActionScheduleManager.shared,
			defaultContentPath: path
		)
		return contentListVC
	}
	
    func showWebView(url: URL, federated: [String: Any]?, resetLocalStorage: Bool? = false) -> OrchextraViewController? {
        guard let webview = try? WebVC.instantiateFromStoryboard() else {
            logWarn("WebVC not found")
            return nil
        }
        
        let passbookWrapper: PassBookWrapper = PassBookWrapper()
        let webInteractor: WebInteractor = WebInteractor(passbookWrapper: passbookWrapper, federated: federated, resetLocalStorage: resetLocalStorage)
        let webPresenter: WebPresenter = WebPresenter(webInteractor: webInteractor, webView: webview)
        
        webview.url = url
        webview.dismissableDelegate = self
        webview.localStorage = Session.shared.localStorage
        webview.presenter = webPresenter
        return webview
	}

    func showYoutubeVC(videoId: String) -> OrchextraViewController? {
        guard let youtubeVC = try? YoutubeVC.instantiateFromStoryboard() else { return nil }
        youtubeVC.loadVideo(identifier: videoId)
        return youtubeVC
    }
    
    func showVideoPlayerVC(with video: Video) -> OrchextraViewController? {
        guard let vimeoAccessToken = Config.providers.vimeo?.accessToken else { return nil }
        let viewController = VideoPlayerVC()
        let wireframe = VideoPlayerWireframe()
        let vimeoWrapper = VimeoWrapper(
            service: VimeoService(accessToken: vimeoAccessToken)
        )
        let videoInteractor = VideoInteractor(
            vimeoWrapper: vimeoWrapper
        )
        let presenter = VideoPlayerPresenter(
            view: viewController,
            wireframe: wireframe,
            video: video,
            videoInteractor: videoInteractor
        )
        vimeoWrapper.output = videoInteractor
        viewController.presenter = presenter
        return viewController
    }
    
    func showBrowser(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        self.application.presentModal(safariVC)
    }
    
    func show(viewController: UIViewController) {
        self.application.presentModal(viewController)
    }
    
    func showCards(_ cards: [Card]) -> OrchextraViewController? {
        guard let viewController = try? CardsVC.instantiateFromStoryboard() else { return nil }
        let presenter = CardsPresenter(
            view: viewController,
            cards: cards
        )
        viewController.presenter = presenter
        return viewController
    }
    
    func showArticle(_ article: Article) -> OrchextraViewController? {
        guard let articleVC = try? ArticleViewController.instantiateFromStoryboard() else {
            logWarn("Couldn't instantiate ArticleViewController")
            return nil
        }
        let presenter = ArticlePresenter(
            article: article,
            actionInteractor: ActionInteractor(
                contentDataManager: .sharedDataManager
            ),
            reachability: ReachabilityWrapper.shared
        )
        if let vimeoAccessToken = Config.providers.vimeo?.accessToken {
            let videoInteractor = VideoInteractor(
                vimeoWrapper: VimeoWrapper(
                    service: VimeoService(
                        accessToken: vimeoAccessToken
                    )
                )
            )
            videoInteractor.output = presenter
            presenter.videoInteractor = videoInteractor
        }
        presenter.viewer = articleVC
        articleVC.presenter = presenter
        return articleVC
    }
    
    func showMainComponent(with action: Action, viewController: UIViewController) {

        let storyboard = UIStoryboard.init(name: "MainContent", bundle: Bundle.OCMBundle())
        
        guard let mainContentVC = storyboard.instantiateViewController(withIdentifier: "MainContentViewController") as? MainContentViewController
            else {
                logWarn("Couldn't instantiate MainContentViewController")
                return
        }
        
        let presenter = MainPresenter(action: action)
        presenter.view = mainContentVC
        mainContentVC.presenter = presenter

        if let contentListVC = viewController as? ContentListVC {
            contentListVC.transitionManager = ContentListTransitionManager(contentListVC: contentListVC, mainContentVC: mainContentVC)
            contentListVC.present(mainContentVC, animated: true, completion: nil)
        } else {
            viewController.show(mainContentVC, sender: nil)
        }
    }
    
    func provideMainComponent(with action: Action) -> UIViewController? {
        let storyboard = UIStoryboard.init(name: "MainContent", bundle: Bundle.OCMBundle())
        guard let mainContentVC = storyboard.instantiateViewController(withIdentifier: "MainContentViewController") as? MainContentViewController
            else {
                logWarn("Couldn't instantiate MainContentViewController")
                return nil
        }
        
        let presenter = MainPresenter(action: action)
        presenter.view = mainContentVC
        mainContentVC.presenter = presenter
        return mainContentVC
    }
    
    // MARK: WebVCDismissable methods
    func dismiss(webVC: WebVC) {
      _ = webVC.navigationController?.popViewController(animated: true)
    }
}
class OCMNavigationController: UINavigationController {
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
}

extension UIApplication {
    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

extension SFSafariViewController {
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        UIApplication.shared.statusBarStyle = .default
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        UIApplication.shared.statusBarStyle = .lightContent
    }
}
