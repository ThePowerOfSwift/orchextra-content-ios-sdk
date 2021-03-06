//
//  ActionContent.swift
//  OCM
//
//  Created by Alejandro Jiménez Agudo on 5/10/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import Foundation
import GIGLibrary


class ActionContent: Action {
    
    var actionType: ActionType
    var customProperties: [String: Any]?
    var elementUrl: String?
    let path: String
    internal var slug: String?
    internal var type: String?
    internal var preview: Preview?
    internal var shareInfo: ShareInfo?
	
    init(preview: Preview?, shareInfo: ShareInfo?, path: String, slug: String?) {
        self.preview = preview
        self.shareInfo = shareInfo
        self.path = path
        self.slug = slug
        self.type = ActionTypeValue.content
        self.actionType = .content
    }
    
	static func action(from json: JSON) -> Action? {
		guard json["type"]?.toString() == ActionTypeValue.content,
		let path = json["render.contentUrl"]?.toString()
            else { return nil }
		let slug = json["slug"]?.toString()
        return ActionContent(
            preview: preview(from: json),
            shareInfo: shareInfo(from: json),
            path: path,
            slug: slug
        )
	}
}
