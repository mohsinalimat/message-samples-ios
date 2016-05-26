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

/**
 Protocol MMViewControllers conform to specifing various functionality useful for displaying, dismissing and setting up view controllers
 */

public protocol MMViewControllerProtocol : class {
    /// The appearence class the controller should use
    var appearance : MagnetControllerAppearance { get }
    /// Sets the navigation bar for an MMViewController
    func setMagnetNavBar(leftItems leftItems:[UIBarButtonItem]?, rightItems:[UIBarButtonItem]?, title : String?)
    /// sets up point for the view controller
    func setupViewController()
    /// dismisses the view controller without animation
    func dismiss()
    /// dismisses the view controller with animation
    func dismissAnimated()
}

/**
 This class is the base class chatkit uses to Implement ViewControllers
 */
public class MMViewController: UIViewController, MMViewControllerProtocol {
    
    
    //MARK: Public Variables
    
    /// - see MMViewControllerProtocol
    public var appearance = MagnetControllerAppearance()
    /// navigationbar
    public var magnetNavigationBar : UINavigationBar?
    /// navigationItems
    public var magnetNavigationItem : UINavigationItem?
    /// called when viewController dismissed
    public var didDismissCompletionBlock : ((viewController : MMViewController) -> Void)?
    
    
    //MARK: Private Variables
    
    
    private let navBarHeight : CGFloat = 54.0
    internal var didGenerateBars = false
    
    
    //MARK: Private Methods
    
    
    private func didDissmisViewController() {
        {[weak self] in
            if let weakSelf = self {
                weakSelf.didDismissCompletionBlock?(viewController: weakSelf)
            }
            }()
    }
    
    
    //MARK : Init
    
    
    /// Init
    public init() {
        super.init(nibName: nil, bundle: nil)
        setupViewController()
    }
    
    /// Init
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /// Init
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupViewController()
    }
    
    /// awakeFromNib
    public override func awakeFromNib() {
        super.awakeFromNib()
        setupViewController()
    }
    
    
    //MARK: Public Methods
    
    
    /**
     sets up the navigations bar
     
     - parameter leftItems: [UIBarButtonItems]? to be added to the left side of the navigation bar
     - parameter rightItems: [UIBarButtonItems]? to be added to the right side of the navigation bar
     - parameter title: the title to be displayed on the navigation bar
     
     - returns: Void
     */
    public func setMagnetNavBar(leftItems leftItems:[UIBarButtonItem]?, rightItems:[UIBarButtonItem]?, title : String?) {
        var willHide = false
        if leftItems == nil && rightItems == nil && title == nil  {
            magnetNavigationBar?.hidden = true
            willHide = true
        }
        
        if let navBar = self.magnetNavigationBar {
            if let tableViewController = self as? MMTableViewController {
                var currentInsets = tableViewController.tableView.contentInset
                currentInsets.top = willHide ? 0 : navBar.frame.size.height
                tableViewController.tableView.contentInset = currentInsets
            }
        }
        
        if willHide {
            return
        }
        
        magnetNavigationBar?.hidden = false
        self.magnetNavigationItem?.leftBarButtonItems = leftItems
        self.magnetNavigationItem?.rightBarButtonItems = rightItems
        self.magnetNavigationItem?.title = title
    }
    
    /**
     sets up viewController called after viewDidLoad
     
     - returns: Void
     */
    public func setupViewController() {
        if let _ = self.view { }
        
        let nav = UINavigationBar(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.navBarHeight))
        nav.autoresizingMask = .FlexibleWidth
        self.view.addSubview(nav)
        let navItem = UINavigationItem()
        nav.items = [navItem]
        magnetNavigationItem = navItem
        magnetNavigationBar = nav
        magnetNavigationBar?.hidden = true
    }
    
    /**
     Dissmisses without animation
     
     - returns: Void
     */
    public func dismiss() {
        if self.navigationController != nil {
            self.navigationController?.popViewControllerAnimated(false)
        } else  {
            self.dismissViewControllerAnimated(false, completion: nil)
        }
        didDissmisViewController()
    }
    
    /**
     Dissmisses with animation
     
     - returns: Void
     */
    public func dismissAnimated() {
        if self.navigationController != nil {
            self.navigationController?.popViewControllerAnimated(true)
            didDissmisViewController()
        } else  {
            self.dismissViewControllerAnimated(true, completion: {
                self.didDissmisViewController()
            })
        }
    }
}
