/*
* Copyright (c) 2016 Magnet Systems, Inc.
* All rights reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License"); you
* may not use this file except in compliance with the License. You
* may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
* implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

import MagnetMax
import UIKit


//MARK: SummaryResponseImageView


class SummaryResponseImageView : MMRoundedImageView {
    
    
    //MARK: Public properties
    
    
    @IBOutlet var imageMinWidth : NSLayoutConstraint?
    
    
    //MARK: Overrides
    
    
    override func updateConstraints() {
        if self.image != nil {
            imageMinWidth?.constant = 40.0
        } else {
            imageMinWidth?.constant = 0.0
        }
        super.updateConstraints()
    }
}


protocol SummaryResponseCellDelegate : class {
    func didSelectSummaryCellAvatar(cell : SummaryResponseCell)
}


//MARK: SummaryResponseCell


class SummaryResponseCell: ChannelDetailBaseTVCell {
    
    
    //MARK: Static properties
    
    
    static var images : [String : UIImage] = [:]
    
    
    //MARK: Public properties
    
    
    @IBOutlet weak var avatarView : UIImageView?
    weak var delegate : SummaryResponseCellDelegate?
    @IBOutlet weak var ivMessageIcon : UIImageView?
    @IBOutlet weak var lblSubscribers : UILabel?
    @IBOutlet weak var lblLastTime : UILabel?
    @IBOutlet weak var lblMessage : UILabel?
    
    
    //MARK: Overridden Properties
    
    
    override var detailResponse : MMXChannelDetailResponse! {
        didSet {
            super.detailResponse = self.detailResponse
            
            var subscribers : [MMUserProfile] = detailResponse.subscribers
            subscribers = subscribers.filter({
                if $0.userId != MMUser.currentUser()?.userID {
                    return true
                }
                return false
            })
            var subscribersTitle = ""
            
            for user in subscribers {
                if let displayName = user.displayName {
                    subscribersTitle += (subscribers.indexOf(user) == subscribers.count - 1) ? displayName : "\(displayName), "
                }
            }
            
            lblSubscribers?.text = subscribersTitle
            
            if let messages = detailResponse.messages, content = messages.last?.messageContent {
                lblMessage?.text = content[Constants.ContentKey.Message] ?? CKStrings.kStr_AttachmentFile
                if content[Constants.ContentKey.Longitude] != nil {
                    lblMessage?.text = CKStrings.kStr_AttachmentLocation
                }
            } else {
                lblMessage?.text = ""
            }
            
            lblLastTime?.text = ChannelManager.sharedInstance.formatter.displayTime(detailResponse.lastPublishedTime!)
        }
    }
    
    
    //MARK: Actions
    
    
    func didSelectAvatar() {
        self.delegate?.didSelectSummaryCellAvatar(self)
    }
    
    
    //MARK: Overrides
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let tap = UITapGestureRecognizer(target: self, action: "didSelectAvatar")
        tap.cancelsTouchesInView = true
        tap.delaysTouchesBegan = true
        self.avatarView?.userInteractionEnabled = true
        self.avatarView?.addGestureRecognizer(tap)
        
        if let ivMessageIcon = ivMessageIcon {
            ivMessageIcon.layer.cornerRadius = ivMessageIcon.bounds.width / 2
            ivMessageIcon.clipsToBounds = true
        }
    }
}
