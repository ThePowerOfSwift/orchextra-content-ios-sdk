//
//  VideoInteractor.swift
//  OCM
//
//  Created by José Estela on 5/10/17.
//  Copyright © 2017 Gigigo SL. All rights reserved.
//

import Foundation

protocol VideoInteractorOutput: class {
    func videoInformationLoaded(_ video: Video?)
}

class VideoInteractor {
    
    // MARK: - Attributes
    
    var vimeoWrapper: VimeoDataManagerInput
    weak var output: VideoInteractorOutput?
    
    // MARK: - Initializers
    
    init(vimeoWrapper: VimeoDataManagerInput) {
        self.vimeoWrapper = vimeoWrapper
        self.vimeoWrapper.output = self
    }
    
    // MARK: - Input methods
    
    func loadVideoInformation(for video: Video) {
        switch video.format {
        case .youtube:
            video.previewUrl = "https://img.youtube.com/vi/\(video.source)/hqdefault.jpg"
            self.output?.videoInformationLoaded(video)
        case .vimeo:
            self.vimeoWrapper.getVideo(idVideo: video.source)
        }
    }
}

extension VideoInteractor: VimeoDataManagerOutput {
    
    func getVideoDidFinish(result: VimeoResult) {
        switch result {
        case .succes(video: let video):
            self.output?.videoInformationLoaded(video)
        default:
            self.output?.videoInformationLoaded(nil)
        }
    }
}
