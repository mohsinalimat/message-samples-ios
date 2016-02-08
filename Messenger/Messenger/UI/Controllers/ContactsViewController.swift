//
//  ContactsViewController.swift
//  MMChat
//
//  Created by Kostya Grishchenko on 1/5/16.
//  Copyright © 2016 Kostya Grishchenko. All rights reserved.
//

import UIKit
import MagnetMax

protocol ContactsViewControllerDelegate: class {
    func contactsControllerDidFinish(with selectedUsers: [MMUser])
}

class ContactsViewController: UITableViewController, UISearchResultsUpdating, UISearchBarDelegate {
    
    weak var delegate: ContactsViewControllerDelegate?
    var availableRecipients = [String : [MMUser]]()
    var filteredRecipients = [MMUser]()
    var selectedUsers : [MMUser] = []
    let resultSearchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resultSearchController.searchResultsUpdater = self
        resultSearchController.dimsBackgroundDuringPresentation = false
        resultSearchController.searchBar.sizeToFit()
        resultSearchController.searchBar.returnKeyType = .Done
        resultSearchController.searchBar.setShowsCancelButton(false, animated: false)
        resultSearchController.searchBar.delegate = self
        updateNextButton()
        tableView.tableHeaderView = resultSearchController.searchBar
        tableView.reloadData()
        
        let searchQuery = "userName:*"
        MMUser.searchUsers(searchQuery, limit: 100, offset: 0, sort: "userName:asc", success: { [weak self] users in
            var tempUsers = users
            if let index = tempUsers.indexOf(MMUser.currentUser()!) {
                tempUsers.removeAtIndex(index)
            }
            self?.availableRecipients = self!.createAlphabetDictionary(tempUsers)
            self?.tableView.reloadData()
            }, failure: { error in
                print("[ERROR]: \(error.localizedDescription)")
        })
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        resultSearchController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func cancelAction() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func nextAction() {
        
        delegate?.contactsControllerDidFinish(with: selectedUsers)
        
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if resultSearchController.active {
            return 1
        }
        return availableRecipients.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if resultSearchController.active {
            return filteredRecipients.count
        }
        
        let letters = Array(availableRecipients.keys)
        let letter = letters[section]
        let users = availableRecipients[letter]
        return users!.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("UserCellIdentifier", forIndexPath: indexPath)
        
        var user: MMUser!
        if resultSearchController.active {
            user = filteredRecipients[indexPath.row]
        } else {
            let letters = Array(availableRecipients.keys)
            let letter = letters[indexPath.section]
            let users = availableRecipients[letter]
            user = users![indexPath.row]
        }
        
        let selectedUsers = self.selectedUsers.filter({
            if $0 === user {
                return true
            }
            return false
        })
        
        if selectedUsers.count > 0 && !cell.highlighted {
            tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition:.None)
        }
        
        let attributes = [NSFontAttributeName : UIFont.boldSystemFontOfSize((cell.textLabel?.font.pointSize)!)]
        var title = NSAttributedString()
        if let lastName = user.lastName where lastName.isEmpty == false {
            title = NSAttributedString(string: lastName, attributes: attributes)
        }
        if let firstName = user.firstName where firstName.isEmpty == false {
            if let lastName = user.lastName where lastName.isEmpty == false{
                let firstPart = NSMutableAttributedString(string: "\(firstName) ")
                firstPart.appendAttributedString(title)
                title = firstPart
            } else {
                title = NSAttributedString(string: firstName, attributes: attributes)
            }
        }
        
        cell.textLabel?.attributedText = title
        
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if resultSearchController.active {
            return ""
        }
        let letters = Array(availableRecipients.keys)
        let letter = letters[section]
        return letter
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if resultSearchController.active {
            let user = filteredRecipients[indexPath.row]
            addSelectedUser(user)
        } else {
            let letters = Array(availableRecipients.keys)
            let letter = letters[indexPath.section]
            if let users = availableRecipients[letter] {
                let user = users[indexPath.row]
                addSelectedUser(user)
            }
        }
        updateNextButton()
    }
    
    override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if resultSearchController.active {
            let user = filteredRecipients[indexPath.row]
            removeSelectedUser(user)
        } else {
            let letters = Array(availableRecipients.keys)
            let letter = letters[indexPath.section]
            if let users = availableRecipients[letter] {
                let user = users[indexPath.row]
                removeSelectedUser(user)
            }
        }
        updateNextButton()
    }
    
    // MARK: - UISearchResultsUpdating
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let userArrays = Array(availableRecipients.values)
        var allUsers = [MMUser]()
        for userArray in userArrays {
            allUsers += userArray
        }
        filteredRecipients = allUsers.filter { user in
            let searchString = searchController.searchBar.text!.lowercaseString
            return user.firstName.lowercaseString.containsString(searchString) || user.lastName.lowercaseString.containsString(searchString)
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Private Methods
    
    private func addSelectedUser(selectedUser : MMUser) {
        removeSelectedUser(selectedUser)
        selectedUsers.append(selectedUser)
    }
    
    private func removeSelectedUser(selectedUser : MMUser) {
        selectedUsers = selectedUsers.filter({
            if $0 !== selectedUser {
                return true
            }
            
            return false
        })
    }
    
    private func updateNextButton() {
        self.navigationItem.rightBarButtonItem?.enabled = selectedUsers.count > 0
    }
    
    // MARK: - Helpers
    
    func createAlphabetDictionary(users: [MMUser]) -> [String : [MMUser]] {
        var tempFirstLetterArray = [String]()
        for user in users {
            var letterString = ""
            if let lastName = user.lastName where lastName.isEmpty == false {
                let index: String.Index = lastName.startIndex.advancedBy(1)
                letterString = lastName.substringToIndex(index).uppercaseString
            } else if let firstName = user.firstName where firstName.isEmpty == false {
                let index: String.Index = firstName.startIndex.advancedBy(1)
                letterString = firstName.substringToIndex(index).uppercaseString
            }
            if tempFirstLetterArray.contains(letterString) == false {
                tempFirstLetterArray.append(letterString)
            }
        }
        tempFirstLetterArray.sortInPlace()
        
        var namesForLetters = [String : [MMUser]]()
        for letter in tempFirstLetterArray {
            var usersBeginWithLetter = [MMUser]()
            for user in users {
                if let lastName = user.lastName where lastName.isEmpty == false{
                    if lastName.hasPrefix(letter.uppercaseString) || lastName.hasPrefix(letter.lowercaseString) {
                        usersBeginWithLetter.append(user)
                    }
                } else if let firstName = user.firstName where firstName.isEmpty == false{
                    if firstName.hasPrefix(letter.uppercaseString) || firstName.hasPrefix(letter.lowercaseString) {
                        usersBeginWithLetter.append(user)
                    }
                }
            }
            namesForLetters.updateValue(usersBeginWithLetter, forKey: letter)
        }
        
        return namesForLetters
    }
    
}