//
//  ImageConstants.swift
//  OCM
//
//  Created by Sergio López on 25/10/16.
//  Copyright © 2016 Gigigo SL. All rights reserved.
//

import UIKit

extension UIImage {
    struct OCM {
        static let swipe = UIImage(named: "swipe", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let previewGrading = UIImage(named: "preview_grading", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let previewSmallGrading = UIImage(named: "preview_small_grading", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let playIconPreviewView = UIImage(named: "iconPlay", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let colorPreviewView = UIImage(named: "color", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let shareButtonIcon = UIImage(named: "content_share_button", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let backButtonIcon = UIImage(named: "content_back_button", in: Bundle.OCMBundle(), compatibleWith:nil)
        static let buttonSolidBackground = UIImage(named: "content_button_solid_background", in: Bundle.OCMBundle(), compatibleWith: nil)
    }
}
