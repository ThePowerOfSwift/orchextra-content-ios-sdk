//
//  ContentListVC.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 31/3/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import UIKit
import GIGLibrary

class ContentListVC: OrchextraViewController, Instantiable {
    
    // MARK: - Outlets
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var noContentView: UIView!
    @IBOutlet weak var errorContainterView: UIView!
    @IBOutlet weak var noSearchResultsView: UIView!
    @IBOutlet weak var contentListView: ContentListView!
    
    // MARK: - Properties
    
    var presenter: ContentListPresenter!
    var newContentView: CompletionTouchableView?
    var transitionManager: ContentListTransitionManager?
    fileprivate var contents: [Content] = []
    fileprivate var errorView: ErrorView?
    
    // MARK: - Instantiable
    
    static var identifier =  "ContentListVC"

    // MARK: - View's Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
        self.presenter.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // MARK: - OrchextraViewController overriden methods
    
    override func filter(byTags tags: [String]) {
        self.presenter.userDidFilter(byTag: tags)
    }
    
    override func search(byString string: String) {
        self.presenter?.userDidSearch(byString: string)
    }
    
    // MARK: - Private Helpers
    
    fileprivate func setupView() {
        
        self.contentListView.datasource = self
        self.contentListView.delegate = self
        
        if let loadingView = Config.loadingView {
            self.loadingView.addSubviewWithAutolayout(loadingView.instantiate())
        } else {
            self.loadingView.addSubviewWithAutolayout(LoadingViewDefault().instantiate())
        }
        
        if let noContentView = Config.noContentView {
            self.noContentView.addSubviewWithAutolayout(noContentView.instantiate())
        } else {
            self.noContentView.addSubviewWithAutolayout(NoContentViewDefault().instantiate())
        }
        
        if let noSearchResultsView = Config.noSearchResultView {
            self.noSearchResultsView.addSubviewWithAutolayout(noSearchResultsView.instantiate())
        }
        
        if let errorView = Config.errorView {
            self.errorContainterView.addSubviewWithAutolayout(errorView.instantiate())
        } else {
            self.errorContainterView.addSubviewWithAutolayout(ErrorViewDefault().instantiate())
        }
        
        self.view.backgroundColor = .clear
        
        if let newContentsAvailableView = Config.newContentsAvailableView {
            self.newContentView = CompletionTouchableView()
            guard let newContentView = self.newContentView else { logWarn("newContentView is nil"); return }
            let view = newContentsAvailableView.instantiate()
            view.isUserInteractionEnabled = false
            newContentView.isHidden = true
            self.view.addSubview(newContentView)
            newContentView.set(autoLayoutOptions: [
                .centerX(to: self.view),
                .margin(to: self.view, top: 0)
            ])
            newContentView.addSubview(view, settingAutoLayoutOptions: [
                .margin(to: newContentView, top: 0, bottom: 0, left: 0, right: 0)
            ])
        }
    }
}

extension ContentListVC: ImageTransitionZoomable {
    
    func createTransitionImageView() -> UIImageView {
        guard let unwrappedSelectedImageView = self.contentListView.selectedImageView else { return UIImageView() }
        let imageView = UIImageView(image: unwrappedSelectedImageView.image)
        imageView.contentMode = unwrappedSelectedImageView.contentMode
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.frame = unwrappedSelectedImageView.convert(unwrappedSelectedImageView.frame, to: self.view)
        return imageView
    }
    
    func presentationCompletion(completeTransition: Bool) {
        self.contentListView.selectedImageView?.isHidden = true
    }
    
    func dismissalCompletionAction(completeTransition: Bool) {
        self.contentListView.selectedImageView?.isHidden = false
    }
}

// MARK: - UI

extension ContentListVC: ContentListUI {
    
    func layout(_ layout: Layout) {
        self.contentListView.setLayout(layout)
    }
    
    func state(_ state: ViewState) {
        var loadingViewHidden = true
        var collectionViewHidden = true
        var noContentViewHidden = true
        var noSearchResultsViewHidden = true
        var errorContainterViewHidden = true
        
        switch state {
        case .loading:
            loadingViewHidden = false
        case .showingContent:
            collectionViewHidden = false
        case .noContent:
            noContentViewHidden = false
        case .noSearchResults:
            noSearchResultsViewHidden = false
        case .error:
            errorContainterViewHidden = false
        }
        
        self.loadingView.isHidden = loadingViewHidden
        self.contentListView.isHidden = collectionViewHidden
        self.noContentView.isHidden = noContentViewHidden
        self.noSearchResultsView.isHidden = noSearchResultsViewHidden
        self.errorContainterView.isHidden = errorContainterViewHidden
    }
    
    func show(_ contents: [Content]) {
        self.contents = contents
        self.contentListView.reloadData()
    }
    
    func show(error: String) {
        self.errorView?.set(errorDescription: error)
    }
    
    func showAlert(_ message: String) {
        guard let banner = self.bannerView, banner.isVisible else {
            self.bannerView = BannerView(frame: CGRect(origin: .zero, size: CGSize(width: self.view.width(), height: 50)), message: message)
            self.bannerView?.show(in: self.view, hideIn: 1.5)
            return
        }
    }
    
    func set(retryBlock: @escaping () -> Void) {
        self.errorView?.set(retryBlock: retryBlock)
    }
    
    func showNewContentAvailableView(with contents: [Content]) {
        self.newContentView?.isHidden = false
        self.newContentView?.addAction { [unowned self] in
            self.dismissNewContentAvailableView()
            self.show(contents)
        }
    }
    
    func dismissNewContentAvailableView() {
        self.newContentView?.isHidden = true
    }
    
    func reloadVisibleContent() {
        let visibleCells = self.contentListView.collectionView.visibleCells
        for cell in visibleCells {
            if let contentCell = cell as? ContentCell {
                contentCell.refreshImage()
            }
        }
    }
    
    func stopRefreshControl() {
        self.contentListView.stopRefreshControl()
    }
    
    func displaySpinner(show: Bool) {
        self.showSpinner(show: show)
    }
}

extension ContentListVC: ContentListViewDelegate {
    
    func contentListView(_ contentListView: ContentListView, didSelectContent content: Content) {
        self.presenter.userDidSelectContent(content, viewController: self)
    }
    
    func contentListViewWantsToRefreshContents(_ contentListView: ContentListView) {
        self.presenter.userDidRefresh()
    }
}

extension ContentListVC: ContentListViewDataSource {
    
    func contentListViewNumberOfContents(_ contentListView: ContentListView) -> Int {
        return self.contents.count
    }
    
    func contentListView(_ contentListView: ContentListView, contentForIndex index: Int) -> Content {
        return self.contents[index]
    }
}
