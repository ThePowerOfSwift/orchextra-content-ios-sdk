//
//  ContentListView.swift
//  OCM
//
//  Created by José Estela on 21/2/18.
//  Copyright © 2018 Gigigo SL. All rights reserved.
//

import Foundation
import UIKit

protocol ContentListViewRefreshDelegate: class {
    func contentListViewWillRefreshContents(_ contentListView: ContentListView)
}

protocol ContentListViewPaginationDelegate: class {
    func contentListViewWillPaginate(_ contentListView: ContentListView)
}

protocol ContentListViewDelegate: class {
    func contentListView(_ contentListView: ContentListView, didSelectContent content: Content)
}

protocol ContentListViewDataSource: class {
    func contentListViewNumberOfContents(_ contentListView: ContentListView) -> Int
    func contentListView(_ contentListView: ContentListView, contentForIndex index: Int) -> Content
}

protocol ContentListViewScrollDelegate: class {
    func contentListView(_ contentListView: ContentListView, didScrollWithScrollView scrollView: UIScrollView)
}

class ContentListView: UIView {
    
    // MARK: - Public attributes
    
    weak var delegate: ContentListViewDelegate?
    weak var dataSource: ContentListViewDataSource?
    weak var paginationDelegate: ContentListViewPaginationDelegate? {
        didSet {
            if paginationDelegate == nil {
                self.paginationActivityIndicator?.stopAnimating()
            } else {
                self.paginationActivityIndicator?.startAnimating()
            }
        }
    }
    weak var scrollDelegate: ContentListViewScrollDelegate?
    weak var refreshDelegate: ContentListViewRefreshDelegate? {
        didSet {
            self.configureRefresh()
        }
    }
    var collectionView: UICollectionView?
    weak var selectedImageView: UIImageView?
    var layout: Layout?
    var numberOfItemsPerPage: Int = 1
    var refreshSpinnerOffset: CGFloat = 0.0 {
        didSet {
            self.refreshAnimatingView?.stopAnimating()
            self.refresher?.removeSubviews()
            self.refresher?.removeFromSuperview()
            self.refresher = nil
            self.refreshAnimatingView = nil
            self.configureRefresh()
        }
    }
    
    // MARK: - Private attributes
    
    fileprivate var pageControl: UIPageControl?
    fileprivate var pageControlBottomConstraint: NSLayoutConstraint?
    fileprivate var timer: Timer?
    fileprivate var cellSelected: UIView?
    fileprivate var cellFrameSuperview: CGRect?
    fileprivate var refresher: UIRefreshControl?
    fileprivate var refreshAnimatingView: ImageActivityIndicator?
    fileprivate var paginationActivityIndicator: ImageActivityIndicator?
    fileprivate var originalContentInsets: UIEdgeInsets?
    
    // MARK: - Public methods
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        self.collectionView = UICollectionView(frame: self.frame, collectionViewLayout: layout)
        if let collectionView = self.collectionView {
            self.addSubviewWithAutolayout(collectionView)
        }
        if #available(iOS 11.0, *) {
            self.collectionView?.contentInsetAdjustmentBehavior = .never
        }
        self.setupView()
    }
    
    func reloadData() {
        self.collectionView?.reloadData()
        guard let contents = self.dataSource?.contentListViewNumberOfContents(self) else { return }
        self.showPageControlWithPages(contents)
        self.stopRefreshControl()
        if self.layout?.type == .carousel {
            // Scrol to second item to enable circular behaviour
            self.collectionView?.layoutIfNeeded()
            self.collectionView?.scrollToItem(at: IndexPath(item: 1, section: 0), at: .right, animated: false)
        } else {
            self.collectionView?.scrollToTop()
        }
    }
    
    func insertContents(_ contents: [Content], at index: Int, completion: (() -> Void)?) {
        if self.layout?.type == .carousel {
            guard let contents = self.dataSource?.contentListViewNumberOfContents(self) else { return }
            self.showPageControlWithPages(contents)
        }
        let currentAnimationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        self.collectionView?.performBatchUpdates({
            let indexPaths = contents.enumerated().map({ contentIndex, _ in
                IndexPath(item: index + contentIndex, section: 0)
            })
            self.collectionView?.insertItems(at: indexPaths)
            }, completion: { finished in
                if finished {
                    completion?()
                    UIView.setAnimationsEnabled(currentAnimationsEnabled)
                }
            }
        )
    }
    
    func setLayout(_ layout: Layout) {
        if layout.type != self.layout?.type {
            self.layout = layout
            self.collectionView?.collectionViewLayout = layout.collectionViewLayout()
            self.collectionView?.isPagingEnabled = layout.shouldPaginate()
            let pageControlOffset = Config.contentListCarouselLayoutStyles.pageControlOffset
            if self.layout?.shouldShowPageController() == true {
                if  pageControlOffset < 0 {
                    self.pageControlBottomConstraint?.constant += pageControlOffset
                }
            }
            self.startTimer()
        }
    }
    
    func stopRefreshControl() {
        self.refresher?.endRefreshing()
        self.refreshAnimatingView?.stopAnimating()
    }
    
    func stopPaginationActivityIndicator(_ completion: (() -> Void)?) {
        self.paginationActivityIndicator?.removeFromSuperview()
        self.paginationActivityIndicator = nil
        if let originalInsets = self.originalContentInsets {
            self.collectionView?.contentInset = originalInsets
        }
        completion?()
    }
    
    // MARK: - Private methods
    
    private func configureRefresh() {
        if self.refreshDelegate == nil {
            self.refreshAnimatingView?.stopAnimating()
            self.refresher?.removeSubviews()
            self.refresher?.removeFromSuperview()
            self.refresher = nil
            self.refreshAnimatingView = nil
        } else if self.layout?.shouldPullToRefresh() == true {
            if self.refresher == nil {
                let refreshControl = UIRefreshControl()
                self.collectionView?.alwaysBounceVertical = true
                if let loadingIcon = UIImage.OCM.loadingIcon {
                    refreshControl.tintColor = .clear
                    let indicator = ImageActivityIndicator(frame: CGRect.zero, image: loadingIcon)
                    indicator.tintColor = Config.styles.primaryColor
                    refreshControl.addSubview(indicator, settingAutoLayoutOptions: [
                        .margin(to: refreshControl, top: self.refreshSpinnerOffset, safeArea: true),
                        .centerX(to: refreshControl),
                        .height(20),
                        .width(20)
                        ]
                    )
                    self.refreshAnimatingView = indicator
                } else {
                    refreshControl.tintColor = Config.styles.primaryColor
                }
                refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
                self.collectionView?.addSubview(refreshControl)
                self.refresher = refreshControl
            }
        }
    }
    
    fileprivate func setupView() {
        self.collectionView?.register(UINib(nibName: "ContentListCollectionViewCell", bundle: Bundle.OCMBundle()), forCellWithReuseIdentifier: "ContentCell")
        self.collectionView?.delegate = self
        self.collectionView?.dataSource = self
        self.collectionView?.showsHorizontalScrollIndicator = false
        self.collectionView?.backgroundColor = Config.contentListStyles.backgroundColor
        self.pageControl = UIPageControl()
        guard let pageControl = self.pageControl else { return }
        pageControl.currentPageIndicatorTintColor = Config.contentListCarouselLayoutStyles.activePageIndicatorColor
        pageControl.pageIndicatorTintColor = Config.contentListCarouselLayoutStyles.inactivePageIndicatorColor
        self.addSubview(pageControl, settingAutoLayoutOptions: [
            .margin(to: self, bottom: 20),
            .centerX(to: self)
        ])
        self.pageControlBottomConstraint = self.bottomMargin(of: pageControl)
    }
    
    fileprivate func showPageControlWithPages(_ pages: Int) {
        self.pageControl?.numberOfPages = pages
        if let showPageController = self.layout?.shouldShowPageController() {
            self.pageControl?.isHidden = !showPageController
        }
    }
    
    fileprivate func itemIndexToContentIndex(_ index: Int) -> Int {
        guard let contents = self.dataSource?.contentListViewNumberOfContents(self), self.layout?.type == .carousel else { return index }
        if index == 0 {
            return contents - 1
        } else if index > contents {
            return 0
        } else {
            return index - 1
        }
    }
    
    fileprivate func updatePageIndicator(index: Int) {
        let pageIndex = self.itemIndexToContentIndex(index)
        self.pageControl?.currentPage = pageIndex
    }
    
    fileprivate func currentIndex() -> Int {
        guard let collectionView = self.collectionView else { return 0 }
        let currentIndex = Int(collectionView.contentOffset.x / collectionView.frame.size.width)
        return currentIndex
    }
    
    fileprivate func goRound() {
        let currentIndex = self.currentIndex()
        self.updatePageIndicator(index: currentIndex)
        guard let contents = self.dataSource?.contentListViewNumberOfContents(self) else { return }
        if currentIndex == contents + 1 {
            // Scrolled from previous to last, scroll from first content copy to simulate circular behaviour
            self.collectionView?.scrollToItem(at: IndexPath(item: 1, section: 0), at: .right, animated: false)
        } else if currentIndex == 0 {
            // Scrolled from second to first, scroll from last content copy to simulate circular behaviour
            self.collectionView?.scrollToItem(at: IndexPath(item: contents, section: 0), at: .right, animated: false)
        }
    }
    
    fileprivate func addPaginationIndicator() {
        if let loadingIcon = UIImage.OCM.loadingIcon, let collectionView = self.collectionView, let layout = self.layout, let paginationDelegate = self.paginationDelegate {
            self.paginationActivityIndicator?.stopAnimating()
            self.paginationActivityIndicator = ImageActivityIndicator(frame: CGRect.zero, image: loadingIcon)
            self.originalContentInsets = collectionView.contentInset
            if let paginationActivityIndicator = self.paginationActivityIndicator {
                switch layout.type {
                case .carousel:
                    collectionView.contentInset = UIEdgeInsets(top: collectionView.contentInset.top, left: collectionView.contentInset.left, bottom: collectionView.contentInset.bottom, right: collectionView.contentInset.right + 80)
                    collectionView.addSubview(paginationActivityIndicator, settingAutoLayoutOptions: [
                        .margin(to: collectionView, left: collectionView.contentSize.width + 20),
                        .centerX(to: collectionView)
                        ]
                    )
                case .mosaic, .fullscreen:
                    collectionView.contentInset = UIEdgeInsets(top: collectionView.contentInset.top, left: collectionView.contentInset.left, bottom: collectionView.contentInset.bottom + 80, right: collectionView.contentInset.right)
                    collectionView.addSubview(paginationActivityIndicator, settingAutoLayoutOptions: [
                        .margin(to: collectionView, top: collectionView.contentSize.height + 20),
                        .centerX(to: collectionView)
                        ]
                    )
                }
                paginationDelegate.contentListViewWillPaginate(self)
            }
        }
    }
    
    @objc fileprivate func refreshData() {
        self.refreshAnimatingView?.startAnimating()
        self.refreshDelegate?.contentListViewWillRefreshContents(self)
    }
}

extension ContentListView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let contents = self.dataSource?.contentListViewNumberOfContents(self), self.itemIndexToContentIndex(indexPath.item) < contents else { return logWarn("Index out of range") }
        
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { logWarn("layoutAttributesForItem is nil"); return }
        self.cellFrameSuperview = collectionView.convert(attributes.frame, to: collectionView.superview)
        self.cellSelected = self.collectionView(collectionView, cellForItemAt: indexPath)
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? ContentCell else { logWarn("cell is nil"); return }
        cell.highlighted(true)
        
        self.selectedImageView = cell.imageContent
        
        delay(0.1) { cell.highlighted(false) }
        
        guard let content = self.dataSource?.contentListView(self, contentForIndex: self.itemIndexToContentIndex(indexPath.item)) else { return }
        self.delegate?.contentListView(self, didSelectContent: content)
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ContentCell else { logWarn("cell is nil"); return }
        cell.highlighted(true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ContentCell else { logWarn("cell is nil"); return }
        cell.highlighted(false)
    }
}

extension ContentListView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let contents = self.dataSource?.contentListViewNumberOfContents(self), contents > 0 else {
            return 0
        }
        if self.layout?.type == .carousel {
            // Add a copy from the last content as first item in the collection and a copy
            // of the first content as last item in the collection to enable circular behaviour
            return contents + 2
        } else {
            return contents
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "ContentCell", for: indexPath) as? ContentCell) ?? ContentCell()
        let contentIndex = self.itemIndexToContentIndex(indexPath.item)
        guard let content = self.dataSource?.contentListView(self, contentForIndex: contentIndex) else { return cell }
        cell.bindContent(content)
        if let contents = self.dataSource?.contentListViewNumberOfContents(self) {
            if indexPath.item >= (contents - 2) && (cell.frame.width != 0 && cell.frame.height != 0) {
                if self.paginationActivityIndicator == nil {
                    self.addPaginationIndicator()
                }
            }
        }
        return cell
    }
}

extension ContentListView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let size = self.layout?.sizeofContent(atIndexPath: indexPath, collectionView: collectionView) else {
            return CGSize.zero
        }
        return size
    }
}

extension ContentListView: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.scrollDelegate?.contentListView(self, didScrollWithScrollView: scrollView)
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        self.stopTimer()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard self.layout?.type == .carousel else { return }
        self.startTimer()
        self.goRound()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard self.layout?.type == .carousel else { return }
        self.goRound()
    }
}

private extension ContentListView {
    
    // MARK: - AutoPlay methods
    
    @objc func scrollToNextPage() {
        guard let contents = self.dataSource?.contentListViewNumberOfContents(self) else { return }
        if contents > 0, let nextIndexPath = nextPage() {
            self.collectionView?.scrollToItem(at: nextIndexPath, at: .left, animated: true)
        }
    }
    
    func nextPage() -> IndexPath? {
        guard let collectionView = self.collectionView else { return nil }
        if let currentIndexPath = collectionView.indexPathsForVisibleItems.last {
            let currentItem = currentIndexPath.item
            if currentItem < collectionView.numberOfItems(inSection: currentIndexPath.section) - 1 {
                return IndexPath(item: currentItem + 1, section: currentIndexPath.section)
            } else {
                return IndexPath(item: 0, section: currentIndexPath.section)
            }
        }
        return nil
    }
    
    func startTimer() {
        if self.layout?.shouldAutoPlay() == true {
            let timeInterval = TimeInterval(Config.contentListCarouselLayoutStyles.autoPlayDuration)
            self.timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(scrollToNextPage), userInfo: nil, repeats: true)
        }
    }
    
    func stopTimer() {
        if self.layout?.shouldAutoPlay() == true {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
}
