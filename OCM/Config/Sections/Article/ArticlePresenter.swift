//
//  ArticlePresenter.swift
//  OCM
//
//  Created by Judith Medina on 19/10/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import UIKit

protocol PArticleVC: class {
    func show(article: Article)
    func update(with article: Article)
    func showViewForAction(_ action: Action)
    func showLoadingIndicator()
    func dismissLoadingIndicator()
}

class ArticlePresenter: NSObject, ReachabilityWrapperDelegate {
    
    let article: Article
    weak var viewer: PArticleVC?
    let actionInteractor: ActionInteractor
    let reachability: ReachabilityWrapper
    
    init(article: Article, actionInteractor: ActionInteractor, reachability: ReachabilityWrapper) {
        self.article = article
        self.actionInteractor = actionInteractor
        self.reachability = reachability
    }
    
    func viewIsReady() {
        self.viewer?.show(article: self.article)
        self.reachability.addDelegate(self)
    }
    
    func performAction(of element: Element, with info: Any) {
        
        if element is ElementButton {
            // Perform button's action
            if let action = info as? String {
                self.actionInteractor.action(with: action) { action, _ in
                    if action?.view() != nil, let unwrappedAction = action {
                        self.viewer?.showViewForAction(unwrappedAction)
                    } else {
                        action?.executable()
                    }
                }
            }
        } else if element is ElementRichText {
            // Open hyperlink's URL on web view
            if let URL = info as? URL {
                // Open on Safari VC
                OCM.shared.wireframe.showBrowser(url: URL)
                // Open in WebView VC
                // TODO: Define how the URL should me shown
                // if let webVC = OCM.shared.wireframe.showWebView(url: URL) {
                //    OCM.shared.wireframe.show(viewController: webVC)
                // }
            }
        }
    }
    
    // MARK: - ReachabilityWrapperDelegate
    
    func reachabilityChanged(with status: NetworkStatus) {
        switch status {
        case .reachableViaMobileData, .reachableViaWiFi:
            self.viewer?.showLoadingIndicator()
            self.viewer?.update(with: self.article)
            self.viewer?.dismissLoadingIndicator()
        default:
            break
        }
    }
}
