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

import CocoaLumberjack
import MagnetMax

/**
 This class is the superclass for `MMXChatViewController`s
 
 - see `MMXChatViewController`
 */
public class CoreChatListViewController: MMTableViewController, UISearchBarDelegate, ChatListCellDelegate {
    
    
    //MARK: Public Variables
    
    
    /// Specifies weather channel search is enabled
    public var canSearch : Bool? {
        didSet {
            updateSearchBar()
        }
    }
    /// A limit of messages to preload for each channel when fetching details
    public var channelDetailsMessagesLimit : Int = 10
    /// A limit of subscribers(userInfo objects) to preload for each channel when fetching details
    public var channelDetailsSubscribersLimit : Int = 50
    
    
    /// SearchBar will be auto generated and inserted into the tableview header if not connected to an outlet
    /// To hide set canSearch = false
    @IBOutlet public var searchBar : UISearchBar?
    
    
    //MARK: Internal Variables
    
    
    internal var currentDetailCount = 0
    internal var detailResponses : [MMXChannelDetailResponse] = []
    weak internal var generatedSearchBar : UISearchBar?
    private var resetCounter = 0
    
    
    //MARK: Overrides
    
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    /// Public Initializer
    public override init() {
        super.init(nibName: String(CoreChatListViewController.self), bundle: NSBundle(forClass: CoreChatListViewController.self))
    }
    
    /** Public Initializer
     parmeter coder: a coder
     */
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /// viewDidLoad
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.allowsMultipleSelection = false
        // Indicate that you are ready to receive messages now!
        MMX.start()
        // Handling disconnection
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDisconnect:", name: MMUserDidReceiveAuthenticationChallengeNotification, object: nil)
        
        var nib = UINib.init(nibName: "ChatListCell", bundle: NSBundle(forClass: CoreChatListViewController.self))
        self.tableView.registerNib(nib, forCellReuseIdentifier: "ChatListCell")
        nib = UINib.init(nibName: "LoadingCell", bundle: NSBundle(forClass: CoreChatListViewController.self))
        self.tableView.registerNib(nib, forCellReuseIdentifier: "LoadingCellIdentifier")
        
        // Add search bar
        
        initializeSearchBar()
        
        self.tableView.layer.masksToBounds = true
        if self.canSearch == nil {
            self.canSearch = true
        }
        
        ChannelManager.sharedInstance.addChannelMessageObserver(self, channel:nil, selector: "didReceiveMessage:")
        refreshControl?.addTarget(self, action: "refreshChannelDetail", forControlEvents: .ValueChanged)
        
        infiniteLoading.onUpdate() { [weak self] in
            if let weakSelf = self {
                weakSelf.loadMore(weakSelf.searchBar?.text, offset: weakSelf.currentDetailCount)
            }
        }
        self.resignOnBackgroundTouch()
        BackgroundMessageManager.sharedManager.setup()
    }
    
    /// viewWillAppear
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    /// viewWillDisappear
    override public func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        resignSearchBar()
    }
    
    
    // MARK: Public Methods
    
    
    /**
     Requests channel details and appends channel details to list
     
     - parameter mmxChannels : Channels to be appended
     
     - returns: Void
     */
    public func append(mmxChannels : [MMXChannel]) {
        if mmxChannels.count > 0 {
            // Get all channels the current user is subscribed to
            let context = self.resetCounter
            MMXChannel.channelDetails(mmxChannels, numberOfMessages: channelDetailsMessagesLimit, numberOfSubcribers: channelDetailsSubscribersLimit, success: { detailResponses in
                if context != self.resetCounter {
                    return
                }
                self.loadedChannelDetails(self.currentDetailCount)
                let shouldStopRefreshControl = self.currentDetailCount == 0
                
                self.currentDetailCount += mmxChannels.count
                
                var details = self.filterChannels(detailResponses)
                self.detailResponses.appendContentsOf(details)
                self.detailResponses = self.sort(self.detailResponses)
                self.endDataLoad()
                
                if details.count == 0 && self.hasMore() {
                    self.infiniteLoading.setNeedsUpdate()
                }
                
                self.refreshControl?.endRefreshing()
                DDLogVerbose("[Retrieved] channel details succeeded")
                }, failure: { error in
                    self.endDataLoad()
                    DDLogError("[Error] - retrieving channel details - \(error.localizedDescription)")
            })
        } else {
            self.endDataLoad()
            self.refreshControl?.endRefreshing()
            if self.hasMore() {
                self.infiniteLoading.setNeedsUpdate()
            }
            reloadFooters()
        }
    }
    
    /**
     Clears data and removes all elements from UI
     
     - returns: Void
     */
    public func clearData() {
        self.detailResponses = []
        self.tableView.reloadData()
        self.currentDetailCount = 0
    }
    
    /**
     Deletes a channel and removes the channel from the UI
     
     - parameter channel : Channel to be deleted
     
     - returns: Void
     */
    public func deleteChannel(channel: MMXChannel) {
        guard channel.ownerUserID == MMUser.currentUser()?.userID else {
            return
        }
        
        channel.deleteWithSuccess({[weak self] in
            if let weakSelf = self {
                var ind: Int?
                var details: MMXChannelDetailResponse?
                for i in 0..<weakSelf.detailResponses.count {
                    if channel == weakSelf.detailResponses[i].channel {
                        ind = i
                        details = weakSelf.detailResponses[i]
                        break
                    }
                }
                
                if let index = ind, let detailResponse  = details {
                    weakSelf.detailResponses.removeAtIndex(index)
                    weakSelf.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Fade)
                    weakSelf.onChannelDidLeave(detailResponse.channel, channelDetails : detailResponse)
                    weakSelf.endRefreshing()
                }
            }
            }, failure: { error in
                print(error)
        })
    }
    
    /**
     Leaves a channel and removes the channel from the UI
     
     - parameter channel : Channel to leave
     
     - returns: Void
     */
    public func leaveChannel(channel: MMXChannel) {
        channel.unSubscribeWithSuccess({[weak self] _ in
            if let weakSelf = self {
                var ind: Int?
                var details: MMXChannelDetailResponse?
                for i in 0..<weakSelf.detailResponses.count {
                    if channel == weakSelf.detailResponses[i].channel {
                        ind = i
                        details = weakSelf.detailResponses[i]
                        break
                    }
                }
                
                if let index = ind, let detailResponse  = details {
                    weakSelf.detailResponses.removeAtIndex(index)
                    weakSelf.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Fade)
                    weakSelf.onChannelDidLeave(detailResponse.channel, channelDetails : detailResponse)
                    weakSelf.endRefreshing()
                }
            }
            }, failure: { error in
                print(error)
        })
    }
    
    
    //MARK: Internal Methods
    
    
    internal func cellDidCreate(cell : UITableViewCell) { }
    
    internal func canEditChannel(channel : MMXChannel, channelDetails : MMXChannelDetailResponse) -> Bool {
        return true
    }
    
    internal func cellForChannel(channel : MMXChannel, channelDetails : MMXChannelDetailResponse, indexPath : NSIndexPath) -> UITableViewCell? {
        return nil
    }
    
    internal func cellHeightForChannel(channel : MMXChannel, channelDetails : MMXChannelDetailResponse, indexPath : NSIndexPath) -> CGFloat {
        return 80
    }
    
    internal func didSelectUserAvatar(user : MMUser) { }
    
    internal func editActionsForChannel(channel : MMXChannel, channelDetails : MMXChannelDetailResponse) -> [UITableViewRowAction]? {
        return nil
    }
    
    internal func filterChannels(channelDetails : [MMXChannelDetailResponse]) -> [MMXChannelDetailResponse] {
        return channelDetails
    }
    
    internal func heightForFooter(index : Int) -> CGFloat {
        return 0.0
    }
    
    internal func imageForChannelDetails(imageView : UIImageView, channelDetails : MMXChannelDetailResponse) {
        imageView.image = nil
    }
    
    internal func hasMore()->Bool {
        return false
    }
    
    internal func loadedChannelDetails(offset : Int) { }
    
    internal func loadMore(searchText : String?, offset : Int) { }
    
    internal func numberOfFooters() -> Int { return 0 }
    
    internal func onChannelDidLeave(channel : MMXChannel, channelDetails : MMXChannelDetailResponse) { }
    
    internal func onChannelDidSelect(channel : MMXChannel, channelDetails : MMXChannelDetailResponse) { }
    
    internal func prefersSoftReset() -> Bool {
        return false
    }
    
    internal func refreshChannel(channel : MMXChannel) -> Bool {
        
        var hasChannel = false
        
        for var i = 0; i < detailResponses.count; i++ {
            let details = detailResponses[i]
            if details.channel.channelID == channel.channelID {
                hasChannel = true
                let channelID = details.channel.channelID
                MMXChannel.channelDetails([channel], numberOfMessages: channelDetailsMessagesLimit, numberOfSubcribers: channelDetailsSubscribersLimit, success: { responses in
                    if let channelDetail = responses.first {
                        let oldChannelDetail = self.detailResponses[i]
                        if channelDetail.channel.channelID == channelID && oldChannelDetail.channel.channelID ==  channelID {
                            self.detailResponses.removeAtIndex(i)
                            self.detailResponses.insert(channelDetail, atIndex: i)
                            self.detailResponses = self.sort(self.detailResponses)
                        }
                    }
                    self.tableView.reloadData()
                    
                    DDLogVerbose("[Refresh] channel details succeeded")
                    }, failure: { (error) -> Void in
                        DDLogError("[Error] - retrieving channel details - \(error.localizedDescription)")
                })
                break
            }
        }
        
        return hasChannel
    }
    
    internal func reset() {
        resetCounter += 1
        self.currentDetailCount = 0
        if !prefersSoftReset() {
            clearData()
        }
        var searchText = self.searchBar?.text
        if searchText?.characters.count == 0 {
            searchText = nil
        }
        self.loadMore(searchText, offset: self.currentDetailCount)
    }
    
    internal func shouldAppendChannel(channel : MMXChannel) -> Bool { return true }
    
    internal func shouldUpdateSearchContinuously() -> Bool {
        return true
    }
    
    internal func sort(channelDetails : [MMXChannelDetailResponse]) -> [MMXChannelDetailResponse] {
        return detailsOrderByDate(channelDetails)
    }
    
    internal func tableViewFooter(index : Int) -> UIView {
        return UIView()
    }
    
    
    //MARK: Notifications
    
    
    func didReceiveMessage(mmxMessage: MMXMessage) {
        DDLogVerbose("[Message] message recieved [CoreChatListViewController]")
        if let channel = mmxMessage.channel {
            if !refreshChannel(channel) {
                if self.shouldAppendChannel(channel) {
                    self.append([channel])
                }
            }
        }
    }
    
    
    //MARK: Actions
    
    
    @IBAction func refreshChannelDetail() {
        reset()
    }
    
    
    // MARK: - Notification handler
    
    
    private func didDisconnect(notification: NSNotification) {
        MMX.stop()
    }
    
    
    // MARK: - UISearchBarDelegate
    
    ///UISearchBarDelegate
    public func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    ///UISearchBarDelegate
    public func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    ///UISearchBarDelegate
    public func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.characters.count == 0 {
            self.search("")
            return
        }
        
        if self.shouldUpdateSearchContinuously() {
            self.search(searchText)
        }
    }
    
    ///UISearchBarDelegate
    public func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
        self.search(searchBar.text)
    }
    
    
    //MARK: ChatListCellDelegate
    
    
    func didSelectCellAvatar(cell: ChatListCell) {
        if let user = cell.detailResponse.subscribers.first {
            MMUser.usersWithUserIDs([user.userId], success: {
                users in
                if let user = users.first {
                    self.didSelectUserAvatar(user)
                }
                }, failure: { error in
                    DDLogError("[Error] Retrieving User")
            })
        }
    }
}

public extension CoreChatListViewController {
    
    
    // MARK: - Table view data source and delegate
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        self.footers = ["LOADING"]
        for var i = 0; i < self.numberOfFooters(); i++ {
            self.footers.insert( "USER_DEFINED", atIndex: 0)
        }
        
        return 1 + self.footers.count
    }
    
    ///UITableviewDatasource
    override public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFooterSection(section) {
            return 0
        }
        return detailResponses.count
    }
    
    ///UITableviewDatasource
    override public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if (isWithinLoadingBoundary()) {
            infiniteLoading.setNeedsUpdate()
        }
        
        let detailResponse = detailsForIndexPath(indexPath)
        if let cell : UITableViewCell = cellForChannel(detailResponse.channel, channelDetails : detailResponse, indexPath : indexPath) {
            cellDidCreate(cell)
            
            return cell
        }
        let cell = tableView.dequeueReusableCellWithIdentifier("ChatListCell", forIndexPath: indexPath) as! ChatListCell
        cell.backgroundColor = cellBackgroundColor
        cell.detailResponse = detailResponse
        cell.delegate = self
        if let imageView = cell.avatarView {
            imageForChannelDetails(imageView, channelDetails: detailResponse)
        }
        cellDidCreate(cell)
        
        return cell
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return canEditChannel(detailsForIndexPath(indexPath).channel, channelDetails : detailsForIndexPath(indexPath))
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // iOS8 requires this method to enable editing
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let detailResponse = detailsForIndexPath(indexPath)
        return editActionsForChannel(detailResponse.channel, channelDetails: detailResponse)
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeightForChannel(detailsForIndexPath(indexPath).channel, channelDetails : detailsForIndexPath(indexPath), indexPath : indexPath)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        onChannelDidSelect(detailsForIndexPath(indexPath).channel, channelDetails : detailsForIndexPath(indexPath))
    }
    
    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if identifierForFooterSection(section) == "LOADING" {
            if infiniteLoading.isFinished {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: MMFooterHeightZero))
                view.backgroundColor = UIColor.clearColor()
                return view
            }
            let view = LoadingView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
            view.indicator?.startAnimating()
            return view
        } else if identifierForFooterSection(section) == "USER_DEFINED" {
            if let index = footerSectionIndex(section) {
                return tableViewFooter(index)
            }
        }
        
        return nil
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if identifierForFooterSection(section) == "LOADING" && !infiniteLoading.isFinished {
            return 50.0
        } else if identifierForFooterSection(section) == "USER_DEFINED" {
            if let index = footerSectionIndex(section) {
                return self.heightForFooter(index)
            }
        }
        return MMFooterHeightZero
    }
}


private extension CoreChatListViewController {
    
    
    // MARK: - Private Methods
    
    
    private func detailsForIndexPath(indexPath : NSIndexPath) -> MMXChannelDetailResponse {
        return  detailResponses[indexPath.row]
    }
    
    private func detailsOrderByDate(channelDetails : [MMXChannelDetailResponse]) -> [MMXChannelDetailResponse] {
        let sortedDetails = channelDetails.sort({ (detail1, detail2) -> Bool in
            let formatter = ChannelManager.sharedInstance.formatter
            return formatter.dateForStringTime(detail1.lastPublishedTime)?.timeIntervalSince1970 > formatter.dateForStringTime(detail2.lastPublishedTime)?.timeIntervalSince1970
        })
        return sortedDetails
    }
    
    private func endDataLoad() {
        if !self.hasMore() {
            infiniteLoading.stopUpdating()
        } else {
            infiniteLoading.startUpdating()
        }
        
        infiniteLoading.finishUpdating()
        self.endRefreshing()
    }
    
    private func endRefreshing() {
        tableView.reloadData()
    }
    
    private func initializeSearchBar() {
        if searchBar == nil {
            searchBar = UISearchBar()
            searchBar?.sizeToFit()
            tableView.tableHeaderView = searchBar
            generatedSearchBar = searchBar
        }
        
        searchBar?.returnKeyType = .Search
        if self.shouldUpdateSearchContinuously() {
            searchBar?.returnKeyType = .Done
        }
        searchBar?.setShowsCancelButton(false, animated: false)
        
        searchBar?.delegate = self
    }
    
    private func reloadFooters() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (Int64)(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {() in
            if self.isFooterSection(self.tableView.numberOfSections - 1) {
                self.tableView.reloadSections(NSIndexSet(index : self.tableView.numberOfSections - 1), withRowAnimation: .None)
            }
        })
    }
    
    private func resignSearchBar() {
        if let searchBar = self.searchBar {
            if searchBar.isFirstResponder() {
                searchBar.resignFirstResponder()
            }
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
    
    private func search(searchString : String?) {
        var text : String? = searchString?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if let txt = text where txt.characters.count == 0 {
            text = nil
        }
        reset()
    }
    
    private func updateSearchBar() {
        if generatedSearchBar != nil {
            if let canSearch = self.canSearch where canSearch == true {
                tableView.tableHeaderView = generatedSearchBar
            } else {
                tableView.tableHeaderView = nil
            }
        }
    }
}

