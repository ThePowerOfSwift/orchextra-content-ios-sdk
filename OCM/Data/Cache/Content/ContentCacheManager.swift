//
//  ContentCacheManager.swift
//  OCM
//
//  Created by Jerilyn Goncalves on 13/06/2017.
//  Copyright © 2017 Gigigo SL. All rights reserved.
//

import UIKit
import GIGLibrary

class ContentCacheManager {
    
    /// Singleton
    static let shared = ContentCacheManager()

    /// Private properties
    private let reachability = ReachabilityWrapper.shared
    private let sectionLimit: Int
    private let elementPerSectionLimit: Int
    private var cachedContent: CachedContent
    private var imageCacheManager: ImageCacheManager
    private let contentPersister: ContentPersister

    // MARK: - Lifecycle
    
    private init() {
        self.sectionLimit = 10
        self.elementPerSectionLimit = 21
        self.cachedContent = CachedContent()
        self.imageCacheManager = ImageCacheManager.shared
        self.contentPersister = ContentCoreDataPersister.shared
    }
    
    // MARK: - Private initialization methods
    
    // MARK: - Public methods
    
    /**
     Add description !!!.
     */
    func initializeCache() {
        
        guard Config.offlineSupport else { return }
        
        let sections = self.contentPersister.loadContentPaths()
        for sectionPath in sections {
            self.cachedContent.cache[sectionPath] = []
            if let contents = self.contentPersister.loadContent(with: sectionPath)?.contents {
                self.cache(contents: contents, with: sectionPath, fromPersistentStore: true)
            }
        }
    }
    
    /**
     Caches the given sections, adding the newest sections and removing those that no longer exist.
     
     - paramater sections: An array with the section's path, i.e.: content list path.
     */
    func cache(sections: [String]) {
    
        guard Config.offlineSupport else { return }
        
        let newSections = Set(sections)
        let oldSections = Set(self.cachedContent.cache.keys)
        
        // Remove from dictionary the old sections
        let sectionsToRemove = oldSections.subtracting(newSections)
        for sectionPath in sectionsToRemove {
            self.cachedContent.cache.removeValue(forKey: sectionPath)
            // TODO: Should we clean the cache at this point? maybe?
        }
        
        // Add to dictionary for caching the newest sections (restricted to `sectionLimit`)
        let sectionsToAdd = newSections.subtracting(oldSections)
        for sectionPath in sectionsToAdd where self.cachedContent.cache.count < self.sectionLimit {
            // Add to dictionary for caching
            self.cachedContent.cache[sectionPath] = []
        }
    }
    
    /**
     Caches the contents for a given section (if the section is being cached).
     **Important:** This method will not fire any downloads to cache images. You'll need to call `startCaching`
     to fire that process.
     
     - paramater contents: An array of contents to be cached.
     - paramater sectionPath: The path for the corresponding section, i.e.: content list path.
     */
    func cache(contents: [Content], with sectionPath: String) {
        
        // Ignore if it's not on caching content
        guard Config.offlineSupport, self.cachedContent.cache[sectionPath] != nil else { return }
        
        self.cache(contents: contents, with: sectionPath, fromPersistentStore: false)
    }
    
    /**
     Initializes the caching process. All contents and articles in the cache that are pending to be cached will be
     downloaded from the server.
     */
    func startCaching() {
        
        guard Config.offlineSupport else { return }
        
        for (sectionKey, contentValue) in self.cachedContent.cache {
            for cachedContentDictionary in contentValue {
                for content in cachedContentDictionary.keys {
                    // Start content caching
                    if cachedContentDictionary[content]?.0 != .caching {
                        self.cache(content: content, with: sectionKey)
                    }
                    
                    // Start article caching
                    if cachedContentDictionary[content]?.1?.1 != .caching,
                        let article = cachedContentDictionary[content]?.1?.0 {
                        self.cache(article: article, for: content, with: sectionKey)
                    }
                }
            }
        }
    }
    
    /**
     Evaluates whether a content is currently cached or not.
     
     - parameter action: The content to evaluate.
     - returns: `true` if the content has a cached article or an article with no media, `false` otherwise.
     */
    func isCached(content: Content) -> Bool {
        guard
            Config.offlineSupport,
            let action = self.contentPersister.loadAction(with: content.elementUrl),
            let article = action as? ActionArticle else {
                return false
        }
        return self.cachedContent.isCached(article: article.article)
    }
    
    /**
     Evaluates whether an image should be cached or not, regardless of it's current caching status.
     
     - parameter imagePath: `String` representation of the image's `URL`.
     */
    func shouldCacheImage(with imagePath: String) -> Bool {
        if self.cachedContent.cachedContentForImage(with: imagePath) != nil ||
            self.cachedContent.cachedArticleForImage(with: imagePath) != nil ||
            self.imageCacheManager.isImageCached(imagePath) {
            return true
        }
        return false
    }
    
    /**
     Caches an image, firing a download or restoring from disk.
     
     **Important:** This method should be called **only** for caching images shown on display, since it's a heavy 
     operation that scouts over the cache for determining it's associated content and articles and prioritizes 
     the download of that image (if not cached) over any current downloads.
     
     - paramater imagePath: `String` representation of the image's `URL`.
     - paramater completion: Completion handler to fire when looking for the image in cache is completed, receiving 
     the expected image or an error.
     */
    func cachedImage(with imagePath: String, completion: @escaping ImageCacheCompletion) {
        
        if self.imageCacheManager.isImageCached(imagePath) {
            self.imageCacheManager.cachedImage(with: imagePath, completion: completion)
        } else {
            if let content = self.cachedContent.cachedContentForImage(with: imagePath) {
                //,
                //let sectionPath = self.cachedContent.sectionForCachedContent(content) {
                
                //self.cache(content: content, with: sectionPath, forceDownload: true, completion: completion)
                self.imageCacheManager.cacheImage(
                    for: imagePath,
                    withDependency: content.slug,
                    priority: .high,
                    completion: completion)
                
            } else if let article = self.cachedContent.cachedArticleForImage(with: imagePath) {
                //,
                //let (sectionPath, content) = self.cachedContent.sectionAndContentForCachedArticle(article) {
                
                //self.cache(article: article, for: content, with: sectionPath, forceDownload: true, completion: completion)
                self.imageCacheManager.cacheImage(
                    for: imagePath,
                    withDependency: article.slug,
                    priority: .high,
                    completion: completion)
            }
        }
    }
    
    // MARK: - Private helpers
    
    // MARK: Caching helpers
    
    private func cache(contents: [Content], with sectionPath: String, fromPersistentStore: Bool = true) {
        
        let cacheStatus: ContentCacheStatus = fromPersistentStore ? .cachingFinished : .none
        
        // Cache the first `elementPerSectionLimit` contents
        for content in contents.prefix(elementPerSectionLimit) {
            self.cachedContent.imagesForContent(content)
            var articleCache: ArticleCache?
            if let action = self.contentPersister.loadAction(with: content.elementUrl) {
                if let articleAction = action as? ActionArticle {
                    let article = articleAction.article
                    self.cachedContent.imagesForArticle(article)
                    articleCache = (article, cacheStatus)
                }
            }
            self.cachedContent.cache[sectionPath]?.append([content: (cacheStatus, articleCache)])
        }
    
    }
    
    private func cache(content: Content, with sectionPath: String, forceDownload: Bool = false, completion: ImageCacheCompletion? = nil) {
        
        guard let contentIndex = self.cachedContent.indexOfContent(content: content, in: sectionPath) else { return }
        
        self.cachedContent.cache[sectionPath]?[contentIndex][content]?.0 = .none
        
        // Cache content's media (thumbnail)
        if forceDownload || self.reachability.isReachableViaWiFi() {
            // If there's WiFi, start caching
            self.cachedContent.cache[sectionPath]?[contentIndex][content]?.0 = .caching
            if let imagePath = self.cachedContent.contentImages[content] {
                self.imageCacheManager.cacheImage(
                    for: imagePath,
                    withDependency: content.slug,
                    priority: (forceDownload ? .high : .low),
                    completion: { (image, error) in
                        self.cachedContent.cache[sectionPath]?[contentIndex][content]?.0 = .cachingFinished
                        completion?(image, error)
                })
            }
        } else {
            // If not, don't start caching until there's WiFi
            self.cachedContent.cache[sectionPath]?[contentIndex][content]?.0 = .none
        }
    }
    
    private func cache(article: Article, for content: Content, with sectionPath: String, forceDownload: Bool = false, completion: ImageCacheCompletion? = nil) {
        
        guard let contentIndex = self.cachedContent.indexOfContent(content: content, in: sectionPath) else { return }

        self.cachedContent.cache[sectionPath]?[contentIndex][content]?.1 = (article, .none)

        // Cache article's image elements (thumbnail)
        if forceDownload || self.reachability.isReachableViaWiFi() {
            // If there's WiFi, start caching
            self.cachedContent.cache[sectionPath]?[contentIndex][content]?.1?.1 = .caching
            if let imagePaths = self.cachedContent.articleImages[article] {
                for imagePath in imagePaths {
                    self.imageCacheManager.cacheImage(
                        for: imagePath,
                        withDependency: article.slug,
                        priority: .low,
                        completion: { (image, error) in
                            self.cachedContent.cache[sectionPath]?[contentIndex][content]?.1?.1 = .cachingFinished
                            completion?(image, error)
                    })
                }
            }
        }
    }
    
    private func cancelCachingForContent(_ content: Content, in sectionPath: String) {
        
        guard let contentIndex = self.cachedContent.indexOfContent(content: content, in: sectionPath) else { return }

        if let aux = self.cachedContent.cache[sectionPath]?[contentIndex][content]?.0, (aux == .caching || aux == .cachingPaused) {
            self.cachedContent.cache[sectionPath]?[contentIndex][content]?.0 = .cachingFinished
            self.imageCacheManager.cancelCachingWithDependency(content.slug)
        }
    }
    
    private func cancelCachingArticle(_ article: Article, with content: Content, in sectionPath: String) {
        
        guard let contentIndex = self.cachedContent.indexOfContent(content: content, in: sectionPath) else { return }

        if let aux = self.cachedContent.cache[sectionPath]?[contentIndex][content]?.1?.1, (aux == .caching || aux == .cachingPaused) {
            self.cachedContent.cache[sectionPath]?[contentIndex][content]?.1?.1 = .cachingFinished
            self.imageCacheManager.cancelCachingWithDependency(article.slug)
        }
    }
    
    func pauseCaching() {
        
        guard Config.offlineSupport else { return }
        
        for (sectionKey, contentValue) in self.cachedContent.cache {
            for (index, cachedContentDictionary) in contentValue.enumerated() {
                for content in cachedContentDictionary.keys {
                    // Pause content being cached
                    if cachedContentDictionary[content]?.0 != .caching {
                        self.cachedContent.cache[sectionKey]?[index][content]?.0 = .cachingPaused
                    }
                    // Pause articles being cached
                    if cachedContentDictionary[content]?.1?.1 != .caching {
                        self.cachedContent.cache[sectionKey]?[index][content]?.1?.1 = .cachingPaused
                    }
                }
            }
        }
        self.imageCacheManager.pauseCaching()
    }
    
    func resumeCaching() {
        
        guard Config.offlineSupport else { return }
        
        for (sectionKey, contentValue) in self.cachedContent.cache {
            for (index, cachedContentDictionary) in contentValue.enumerated() {
                for content in cachedContentDictionary.keys {
                    
                    // Resume paused content caching
                    if cachedContentDictionary[content]?.0 == .cachingPaused {
                        self.cachedContent.cache[sectionKey]?[index][content]?.0 = .caching
                    }
                    
                    // Resume paused articles caching
                    if cachedContentDictionary[content]?.1?.1 != .cachingPaused {
                        self.cachedContent.cache[sectionKey]?[index][content]?.1?.1 = .caching
                    }
                }
            }
        }
        
        self.imageCacheManager.resumeCaching()
    }
    
    func cancelCaching() {
        
        guard Config.offlineSupport else { return }
        
        for (sectionKey, contentValue) in self.cachedContent.cache {
            for (index, cachedContentDictionary) in contentValue.enumerated() {
                for content in cachedContentDictionary.keys {
                    
                    // Cancel content caching
                    self.cachedContent.cache[sectionKey]?[index][content]?.0 = .cachingFinished
                    
                    // Cancel article caching
                    self.cachedContent.cache[sectionKey]?[index][content]?.1?.1 = .cachingFinished
                }
            }
        }
    }
    
    // MARK: - Reachability Change
    
    @objc func reachabilityChanged(_ notification: NSNotification) {
        
//        guard let reachability = notification.object as? Reachability else { return }
//
//        if reachability.isReachable {
//            if reachability.isReachableViaWiFi {
//                // Start caching process when in WiFi
//                self.resumeCaching()
//            } else {
//                // Stop caching process when in 3G, 4G, etc.
//                self.pauseCaching()
//            }
//        }
    }
    
}
