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

import MagnetMax


//MARK: MagnetChatViewController


public class MMXChatViewController: CoreChatViewController, Define_MMXChatViewController {
    
    
    //Private Variables
    
    
    private var requestNumber : Int = 0
    
    
    //MARK: Public Variables
    
    
    public var channel : MMXChannel? {
        get {
            return chat
        }
    }
    
    public var datasource : ChatViewControllerDatasource? {
        willSet {
            if let datasource = self.datasource as? DefaultChatViewControllerDatasource {
                datasource.controller = nil
            }
        }
        didSet {
            if let datasource = self.datasource as? DefaultChatViewControllerDatasource {
                datasource.controller = self
                reset()
            }
        }
    }
    
    public var delegate : ChatViewControllerDelegate? {
        didSet {
            if let delegate = self.delegate as? DefaultChatViewControllerDelegate {
                delegate.controller = self
            }
        }
    }
    
    public var showDetails = true
    
    public var useNavigationBarNotifier : Bool? {
        didSet {
            if useNavigationBarNotifier == true {
                navigationBarNotifier = NavigationNotifier(viewController: self, exceptFor: self.channel)
            } else {
                navigationBarNotifier = nil
            }
        }
    }
    
    public override var chat  : MMXChannel? {
        didSet {
            useNavigationBarNotifier = true
            reset()
        }
    }
    
    
    //These can be overridden to inject datasources, delegates and other customizations into the variable on didSet
    
    
    public weak var chatDetailsViewController : MMXContactsPickerController?
    public weak var chatDetailsDataSource : SubscribersDatasource? {
        didSet {
            chatDetailsDataSource?.controller = chatDetailsViewController
            chatDetailsDataSource?.channel = self.channel
            chatDetailsDataSource?.chatViewController = self
            
            if let viewControllers  = self.navigationController?.viewControllers where viewControllers.count > 1  {
                if let lastViewController = viewControllers[viewControllers.count - 2] as? MMXChatListViewController {
                    chatDetailsDataSource?.chatListViewController = lastViewController
                }
            }
            chatDetailsViewController?.datasource = self.chatDetailsDataSource
        }
    }
    
    
    //MARK: Init
    
    
    public override init() {
        useNavigationBarNotifier = false
        super.init()
    }
    
    public convenience init(channel : MMXChannel) {
        self.init()
        self.chat = channel
    }
    
    public convenience init(recipients : [MMUser]) {
        self.init()
        self.recipients = recipients
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    //MARK: Public Methods
    
    
    override public func append(mmxMessages: [MMXMessage]) {
        super.append(mmxMessages)
    }
    
    internal override func hasMore() -> Bool {
        if let datasource = self.datasource {
            return datasource.mmxControllerHasMore()
        }
        return super.hasMore()
    }
    
    public func loadingContext() -> Int {
        return self.requestNumber
    }
    
    
    //MARK: Reload methods
    
    
    public override func clearData() {
        super.clearData()
    }
    
    public func reloadData() {
        self.append([])
    }
    
    public func resetData() {
        self.reset()
    }
    
    //MARK: Overrides
    
    
    override public func setupViewController() {
        super.setupViewController()
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        if self.datasource == nil {
            self.datasource = DefaultChatViewControllerDatasource()
        }
        
        if self.delegate == nil {
            self.delegate = DefaultChatViewControllerDelegate()
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.tintColor = self.appearance.tintColor
    }
    
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        assert(self.navigationController != nil, "MMXChatViewController must be presented using a Navagation Controller")
        
        generateNavBars()
    }
    
    
    //MARK: Private Methods
    
    
    private func generateNavBars() {
        if showDetails && !didGenerateBars {
            didGenerateBars = true
            let rightBtn = UIBarButtonItem.init(title: "Details", style: .Plain, target: self, action: "detailsAction")
            if self.navigationItem.rightBarButtonItems != nil {
                self.navigationItem.rightBarButtonItems?.insert(rightBtn, atIndex: 0)
            } else {
                self.navigationItem.rightBarButtonItems = [rightBtn]
            }
        }
        
        if channel == nil {
            self.navigationItem.rightBarButtonItem?.enabled = false
        }
    }
    
    private func newLoadingContext() {
        self.requestNumber++
    }
    
    
    //MARK: Actions
    
    
    public func detailsAction() {
        
        if let currentUser = MMUser.currentUser() {
            let detailsViewController = MMXContactsPickerController(ignoredUsers: [currentUser])
            
            detailsViewController.barButtonNext = nil
            let subDatasource = SubscribersDatasource()
            
            detailsViewController.tableView.allowsSelection = false
            detailsViewController.canSearch = false
            detailsViewController.title = CKStrings.kStr_Subscribers
            
            self.chatDetailsViewController = detailsViewController
            self.chatDetailsDataSource = subDatasource
            
            if let detailsVC = self.chatDetailsViewController {
                self.navigationController?.pushViewController(detailsVC, animated: true)
            }
        }
    }
    
    
    //MARK: - Core Method Overrides
    
    override public func didPressAccessoryButton(sender: UIButton!) {
        super.didPressAccessoryButton(sender)
        
        if let rawTypes = self.datasource?.mmxAttachmentTypes?() {
            var labels = [String]()
            var types = [AttachmentTypes]()
            for rawType in rawTypes {
                if let type = AttachmentTypes(rawValue: rawType) {
                    let label = self.datasource!.mmxDisplayNameForAttachmentType!(rawType)
                    labels.append(label)
                    types.append(type)
                }
            }
            handleAttachments(labels, types: types)
        }
    }
    
    override internal func didSelectUserAvatar(user: MMUser) {
        self.delegate?.mmxAvatarDidClick?(user)
    }
    
    override internal func loadMore(channel : MMXChannel?, offset: Int) {
        self.datasource?.mmxControllerLoadMore(channel, offset: offset)
    }
    
    override internal func onChannelCreated(mmxChannel: MMXChannel) {
        self.useNavigationBarNotifier = true
        self.delegate?.mmxChatDidCreateChannel(mmxChannel)
    }
    
    override internal func onMessageRecived(mmxMessage: MMXMessage) {
        self.delegate?.mmxChatDidRecieveMessage(mmxMessage)
    }
    
    override internal func onMessageSent(mmxMessage: MMXMessage) {
        self.delegate?.mmxChatDidSendMessage(mmxMessage)
    }
    
    override internal func prefersSoftReset() -> Bool {
        if let shouldSoftReset = self.datasource?.mmxControllerPrefersSoftResets {
            return shouldSoftReset()
        }
        
        return super.prefersSoftReset()
    }
}