//
//  RearMenuViewController.swift
//  MMChat
//
//  Created by Kostya Grishchenko on 1/5/16.
//  Copyright © 2016 Kostya Grishchenko. All rights reserved.
//

import UIKit
import MagnetMax

class RearMenuViewController: UITableViewController {
    
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var userAvatar: UIImageView!

    
    enum IndexPathRowAction: Int {
        case UserInfo = 0
        case Home 
//        case Events
        case SignOut
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MMX.start()
        // Handling disconnection
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDisconnect:", name: MMUserDidReceiveAuthenticationChallengeNotification, object: nil)
        
        userAvatar.layer.cornerRadius = userAvatar.frame.size.width/2
        userAvatar.layer.masksToBounds = true
        
    }
    
    override func viewWillAppear(animated: Bool) {
        if let user = MMUser.currentUser() {
            username.text = "\(user.firstName ?? "") \(user.lastName ?? "")"

            Utils.loadUserAvatar(user, toImageView: self.userAvatar, placeholderImage: UIImage(named: "user_default")!)
        }
    }

    
    // MARK: - Table view delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch indexPath.row {
        case IndexPathRowAction.UserInfo.rawValue:
            self.revealViewController().revealToggleAnimated(true)
            self.revealViewController().presentViewController((self.storyboard?.instantiateViewControllerWithIdentifier(vc_id_UserProfile))!, animated: true, completion: nil)
        case IndexPathRowAction.SignOut.rawValue :
            
            let confirmationAlert = Popup(message: kStr_SignOutAsk, title: kStr_SignOut, closeTitle: kStr_No)
            let okAction = UIAlertAction(title: kStr_Yes, style: .Default) { action in
                MMUser.logout({() -> Void in
                    print("[SESSION]: SESSION ENDED BY USER")
                    }, failure: { (error) -> Void in
                        print("[ERROR]: \(error)")
                })
            }
            confirmationAlert.addAction(okAction)
            confirmationAlert.presentForController(self)

        case IndexPathRowAction.Home.rawValue :
            let storyboard = UIStoryboard(name: sb_id_Main, bundle: nil)
            let vc = storyboard.instantiateViewControllerWithIdentifier(vc_id_Home);
            self.revealViewController().pushFrontViewController(vc, animated: true);
//        case IndexPathRowAction.Events.rawValue:
//            let storyboard = UIStoryboard(name: sb_id_Main, bundle: nil)
//            let vc = storyboard.instantiateViewControllerWithIdentifier(vc_id_Events);
//            self.revealViewController().pushFrontViewController(vc, animated: true);
        default:break;
        }

        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    private func didDisconnect(notification: NSNotification) {
        // Indicate that you are not ready to receive messages now!
        MMX.stop()
        
        // Redirect to the login screen
        if let revealVC = self.revealViewController() {
            revealVC.rearViewController.navigationController?.popToRootViewControllerAnimated(true)
        }
    }
}
