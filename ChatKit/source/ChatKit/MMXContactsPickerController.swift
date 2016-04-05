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


//MARK: MagnetContactsPickerController


public class MMXContactsPickerController: CoreContactsViewController, Define_MMXContactsPickerController {
    
    
    //MARK: Static Methods
    
    
    static public var globallyIgnoredUsers : [MMUser] = []
    
    
    //Private Variables
    
    
    private var requestNumber : Int = 0
    
    
    //MARK: Public Variables
    
    
    public var barButtonCancel : UIBarButtonItem?
    public var barButtonNext : UIBarButtonItem?
    public weak var delegate : ContactsControllerDelegate?
    
    public var datasource : ContactsControllerDatasource? {
        willSet {
            if let datasource = self.datasource as? DefaultContactsPickerControllerDatasource {
                datasource.controller = nil
            }
        }
        didSet {
            if let datasource = self.datasource as? DefaultContactsPickerControllerDatasource {
                datasource.controller = self
                self.datasource?.mmxContactsControllerRegisterCells?(tableView)
                reset()
            }
        }
    }
    
    //MARK: Init
    
    
    convenience public init(ignoredUsers: [MMUser]) {
        self.init()
        var hash  : [String : MMUser] = [:]
        for user in ignoredUsers {
            if let userId = user.userID {
                hash[userId] = user
            }
        }
        self.ignoredUsers = hash
    }
    
    
    //MARK: Overrides
    
    
    override public func setupViewController() {
        self.refreshControl = nil
        
        super.setupViewController()
        
        var hash  = ignoredUsers
        for user in MMXContactsPickerController.globallyIgnoredUsers {
            if let userId = user.userID {
                hash[userId] = user
            }
        }
        ignoredUsers = hash
        
        self.title = "Contacts"
        let btnNext = UIBarButtonItem.init(title: "Next", style: .Plain, target: self, action: "nextAction")
        let btnCancel = UIBarButtonItem.init(title: "Cancel", style: .Plain, target: self, action: "cancelAction")
        barButtonCancel = btnCancel
        barButtonNext = btnNext
        
        if self.datasource == nil {
            self.datasource = DefaultContactsPickerControllerDatasource()
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        if let selectedUsers = self.datasource?.mmxContactsControllerPreselectedUsers?() {
            self.selectedUsers = selectedUsers
        }
        self.view.tintColor = self.appearance.tintColor
    }
    
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        assert(self.navigationController != nil, "MMXContactsPickerController must be presented using a Navagation Controller")
        
        generateNavBars()
        self.updateButtonItems()
    }
    
    
    //MARK : Private Methods
    
    
    private func generateNavBars() {
        if let btnCancel = barButtonCancel, let btnNext = barButtonNext where !didGenerateBars {
            didGenerateBars = true
            if self.navigationItem.rightBarButtonItems != nil {
                self.navigationItem.rightBarButtonItems?.append(btnNext)
            } else {
                self.navigationItem.rightBarButtonItems = [btnNext]
            }
            
            if self.navigationItem.leftBarButtonItems != nil {
                self.navigationItem.leftBarButtonItems?.append(btnCancel)
            } else {
                self.navigationItem.leftBarButtonItems = [btnCancel]
            }
        }
    }
    
    private func newLoadingContext() {
        self.requestNumber++
    }
    
    private func updateButtonItems() {
        self.navigationItem.rightBarButtonItem?.enabled = self.selectedUsers.count > 0
    }
    
    
    //Public Methods
    
    
    override public func append(unfilteredUsers: [MMUser]) {
        super.append(unfilteredUsers)
    }
    
    public func contacts() -> [[String : [MMUser]?]] {
        return self.availableRecipients.map({ (group) -> [String : [MMUser]?] in
            let letter = "\(group.letter)"
            let users = group.users.map({$0.user}) as? [MMUser]
            return [letter : users]
        })
    }
    
    public func loadingContext() -> Int {
        return self.requestNumber
    }
    
    public func reloadData() {
        self.append([])
    }
    
    public func resetData() {
        self.reset()
    }
    
    
    //MARK: Actions
    
    
    func cancelAction() {
        self.dismissAnimated()
    }
    
    func nextAction() {
        barButtonNext?.enabled = false
        self.didDismissCompletionBlock = { (viewController : MMViewController) in
            if let vc = viewController as? MMXContactsPickerController {
                vc.barButtonNext?.enabled = true
            }
        }
        self.delegate?.mmxContactsControllerDidFinish?(with: self.selectedUsers)
        cancelAction()
    }
    
    
    //MARK: - Core Method Overrides
    
    
    override func canSelectUser(user: MMUser) -> Bool {
        if let selectUser = self.delegate?.mmxContactsCanSelectUser {
            return selectUser(user)
        }
        
        return super.canSelectUser(user)
    }
    
    override internal func cellDidCreate(cell: UITableViewCell) {
        self.datasource?.mmxContactsDidCreateCell?(cell)
    }
    
    override internal func cellForUser(user: MMUser, indexPath: NSIndexPath) -> UITableViewCell? {
        return self.datasource?.mmxContactsCellForUser?(tableView, user: user, indexPath: indexPath)
    }
    
    override internal func cellHeightForUser(user: MMUser, indexPath: NSIndexPath) -> CGFloat {
        if let height = self.datasource?.mmxContactsCellHeightForUser?(user, indexPath: indexPath) {
            return height
        }
        return super.cellHeightForUser(user, indexPath: indexPath)
    }
    
    override internal func didSelectUserAvatar(user: MMUser) {
        self.delegate?.mmxAvatarDidClick?(user)
    }
    
    override internal func imageForUser(imageView: UIImageView, user: MMUser) {
        if let imgForUser = self.datasource?.mmxContactsControllerImageForUser {
            imgForUser(imageView, user: user)
        } else {
            super.imageForUser(imageView, user: user)
        }
    }
    
    override internal func hasMore() -> Bool {
        if let pickerDatasource = self.datasource {
            return pickerDatasource.mmxControllerHasMore()
        }
        return false
    }
    
    override internal func heightForFooter(index: Int) -> CGFloat {
        if let height = self.datasource?.mmxTableViewFooterHeight?(index) {
            return height
        }
        
        return 0.0
    }
    
    override internal func loadMore(searchText : String?, offset : Int) {
        newLoadingContext()
        if searchText != nil {
            let loadingContext = self.loadingContext()
            //cool down
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (Int64)(0.3 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {() in
                if loadingContext != self.loadingContext() {
                    return
                }
                self.datasource?.mmxControllerLoadMore(searchText, offset : offset)
            })
        } else {
            self.datasource?.mmxControllerLoadMore(searchText, offset : offset)
        }
    }
    
    override internal func numberOfFooters() -> Int {
        if let number = self.datasource?.mmxTableViewNumberOfFooters?() {
            return number
        }
        
        return 0
    }
    
    override internal func onUserDeselected(user: MMUser) {
        self.updateButtonItems()
        self.delegate?.mmxContactsControllerUnSelectedUser?(user)
    }
    
    override internal func onUserSelected(user: MMUser) {
        self.updateButtonItems()
        self.delegate?.mmxContactsControllerSelectedUser?(user)
    }
    
    override internal func shouldShowHeaderTitles() -> Bool {
        if let pickerDatasource = self.datasource {
            if let shows = pickerDatasource.mmxContactsControllerShowsSectionsHeaders?() {
                return shows
            }
        }
        return false
    }
    
    override internal func shouldShowIndexTitles() -> Bool {
        if let pickerDatasource = self.datasource {
            if let shows = pickerDatasource.mmxContactsControllerShowsSectionIndexTitles?() {
                return shows
            }
        }
        return false
    }
    
    override internal func shouldUpdateSearchContinuously() -> Bool {
        if let pickerDatasource = self.datasource {
            return pickerDatasource.mmxControllerSearchUpdatesContinuously()
        }
        return false
    }
    
    override internal func tableViewFooter(index: Int) -> UIView {
        if let footer = self.datasource?.mmxTableViewFooter?(index) {
            return footer
        }
        
        return super.tableViewFooter(index)
    }
}
