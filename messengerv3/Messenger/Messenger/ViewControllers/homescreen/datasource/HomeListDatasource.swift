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

import UIKit
import ChatKit


//MARK: datasource for first screen


class HomeListDatasource : DefaultChatListControllerDatasource {
    
    
    //MARK: Internal Variables
    
    
    var loadingGroup : dispatch_group_t = dispatch_group_create()
    var eventChannels : [MMXChannel] = []
    var askMagnet : MMXChannel?
    
    
    //MARK: custom overrides
    
    
    func mmxListSortChannelDetails(channelDetails: [MMXChannelDetailResponse]) -> [MMXChannelDetailResponse] {
        
        let details = channelDetails.sort({ (detail1, detail2) -> Bool in
            let formatter = ChannelManager.sharedInstance.formatter
            return formatter.dateForStringTime(detail1.lastPublishedTime)?.timeIntervalSince1970 > formatter.dateForStringTime(detail2.lastPublishedTime)?.timeIntervalSince1970
        })
        
        let eventChannels = details.filter({$0.channelName.hasPrefix("global_") && !$0.channelName.hasPrefix(kAskMagnetChannel)})
        let askMagnetChannel = details.filter({$0.channelName.hasPrefix(kAskMagnetChannel)}).first
        let otherChannels = details.filter({!$0.channelName.hasPrefix("global_") && !$0.channelName.hasPrefix(kAskMagnetChannel)})
        
        var results : [MMXChannelDetailResponse] = []
        
        if eventChannels.count > 0 {
            results.appendContentsOf(eventChannels)
        }
        
        if let askMagnet = askMagnetChannel {
            results.append(askMagnet)
        }
        
        if otherChannels.count > 0 {
            results.appendContentsOf(otherChannels)
        }
        
        return results
    }
    
    override func mmxListRegisterCells(tableView: UITableView) {
        let nib = UINib.init(nibName: "EventsTableViewCell", bundle: NSBundle(forClass: HomeListDatasource.self))
        tableView.registerNib(nib, forCellReuseIdentifier: "EventsTableViewCell")
        
        let nib2 = UINib.init(nibName: "AskMagnetTableViewCell", bundle: NSBundle(forClass: HomeListDatasource.self))
        tableView.registerNib(nib2, forCellReuseIdentifier: "AskMagnetTableViewCell")
    }
    
    func mmxListCellHeightForChannel(channel: MMXChannel, channelDetails: MMXChannelDetailResponse, indexPath: NSIndexPath) -> CGFloat {
        if channelDetails.channelName.hasPrefix("global_") {
            return 170.0
        }
        return 80.0
    }
    
    func mmxListCellForChannel(tableView: UITableView, channel: MMXChannel, channelDetails: MMXChannelDetailResponse, indexPath: NSIndexPath) -> UITableViewCell? {
        if channelDetails.channelName.hasPrefix("global_") {
            if let cell = tableView.dequeueReusableCellWithIdentifier("EventsTableViewCell", forIndexPath: indexPath) as? EventsTableViewCell {
                cell.eventImage?.backgroundColor = UIColor.whiteColor()
                cell.eventDescriptionLabel?.text = channelDetails.channel.summary
                cell.eventImage?.image = nil
                cell.eventSubtitleLabel?.text = "\(channelDetails.subscriberCount) subscribers"
                
                if let summary = channelDetails.channel.summary where summary.containsString("Week") {
                    cell.eventImage?.image = UIImage(named: "bg_img_1_2.png")
                }
                
                cell.detailResponse = channelDetails
                
                return cell
            }
        } else if let summary = channelDetails.channel.summary where summary.containsString("Ask Magnet") {
            if let cell = tableView.dequeueReusableCellWithIdentifier("AskMagnetTableViewCell", forIndexPath: indexPath) as? AskMagnetTableViewCell {
                cell.detailResponse = channelDetails
                
                return cell
            }
        }
        
        return nil
    }
    
    func loadAskMagnetChannel() {
        
        guard !Utils.isMagnetEmployee() else {
            return
        }
        
        dispatch_group_enter(self.loadingGroup)
        MMXChannel.channelForName(kAskMagnetChannel, isPublic: false, success: { channel in
            self.askMagnet = channel
            dispatch_group_leave(self.loadingGroup)
            }, failure: { error in
                // Since channel is not found, attempt to create it
                // Magnet Employees will have the magnetsupport tag
                // Subscribe all Magnet employees
                MMUser.searchUsers("tags:\(kMagnetSupportTag)", limit: 50, offset: 0, sort: "firstName:asc", success: { users in
                    let summary: String
                    if let userName = MMUser.currentUser()?.userName {
                        summary = "Ask Magnet for \(userName)"
                    } else {
                        // We should never be here!
                        summary = "Ask Magnet for anonymous"
                    }
                    MMXChannel.createWithName(kAskMagnetChannel, summary: summary, isPublic: false, publishPermissions: .Subscribers, subscribers: Set(users), success: { channel in
                        self.askMagnet = channel
                        dispatch_group_leave(self.loadingGroup)
                        }, failure: { error in
                            print("[ERROR]: \(error.localizedDescription)")
                            dispatch_group_leave(self.loadingGroup)
                    })
                    }, failure: { error in
                        print("[ERROR]: \(error.localizedDescription)")
                        dispatch_group_leave(self.loadingGroup)
                })
        })
    }
    
    func loadEventChannels() {
        dispatch_group_enter(self.loadingGroup)
        MMXChannel.findByTags( Set(["active"]), limit: 5, offset: 0, success: { total, channels in
            if channels.count > 0 {
                let lock = NSLock()
                self.eventChannels = []
                
                for  channel in channels {
                    dispatch_group_enter(self.loadingGroup)
                    
                    channel.subscribeWithSuccess({
                        
                        lock.lock()
                        self.eventChannels.append(channel)
                        lock.unlock()
                        
                        dispatch_group_leave(self.loadingGroup)
                        }, failure: { (error) -> Void in
                            print("subscribe global error \(error)")
                            dispatch_group_leave(self.loadingGroup)
                    })
                }
            }
            dispatch_group_leave(self.loadingGroup)
        }) { (error) -> Void in
            dispatch_group_leave(self.loadingGroup)
        }
    }
    
    override func subscribedChannels(completion : ((channels : [MMXChannel]) -> Void)) {
        MMXChannel.subscribedChannelsWithSuccess({ ch in
            let cV = ch.filter({ return $0.ownerUserID == MMUser.currentUser()!.userID && !$0.name.hasPrefix("global_") && !$0.name.hasPrefix(kAskMagnetChannel)})
            completion(channels: cV)
        }) { error in
            print(error)
            completion(channels: self.eventChannels)
        }
    }
    
    override func mmxControllerLoadMore(searchText: String?, offset: Int) {
        if offset == 0 {
            self.loadEventChannels()
            self.loadAskMagnetChannel()
        }
        dispatch_group_notify(loadingGroup, dispatch_get_main_queue(),{
            self.hasMoreUsers = offset == 0 ? true : self.hasMoreUsers
            //get request context
            let loadingContext = self.controller?.loadingContext()
            self.subscribedChannels({ channels in
                if loadingContext != self.controller?.loadingContext() {
                    return
                }
                var offsetChannels : [MMXChannel] = []
                if offset < channels.count {
                    offsetChannels = Array(channels[offset..<min((offset + self.limit), channels.count)])
                } else {
                    self.hasMoreUsers = false
                }
                
                if offset == 0 {
                    offsetChannels.appendContentsOf(self.eventChannels)
                    if let askMagnet = self.askMagnet {
                        offsetChannels.append(askMagnet)
                    }
                }
                self.controller?.append(offsetChannels)
            })
        })
    }
    
    override func mmxControllerSearchUpdatesContinuously() -> Bool {
        return false
    }
}