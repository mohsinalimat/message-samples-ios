//
//  ContactsViewController.m
//  ChatKit
//
//  Created by Vladimir Yevdokimov on 3/9/16.
//  Copyright © 2016 Vladimir Yevdokimov. All rights reserved.
//

#import "ContactsViewController.h"

@interface ContactsViewController ()

@property (weak, nonatomic) IBOutlet UITableView *contactsTable;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelBBI;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *createBBI;

@property (nonatomic, strong) NSMutableArray *presentingUsers;

@end

@implementation ContactsViewController
#pragma mark - Class Methods


+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([ContactsViewController class])
                          bundle:[NSBundle bundleForClass:[ContactsViewController class]]];
}

- (void)setupUI
{
    if (self.navigationController) {
        self.navigationItem.leftBarButtonItems = [self leftBarButtonItems];
        self.navigationItem.rightBarButtonItems = [self rightBarButtonItems];
        
        self.navigationItem.title = [self titleString];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_contacts) {
        _presentingUsers = _contacts.mutableCopy;
    } else {
        
        [MMUser searchUsers:@"firstName:*" limit:1000 offset:0 sort:@"firstName:asc" success:^(NSArray<MMUser *> * _Nonnull users) {
            _contacts = users;
            NSLog(@"contacts %@",@(users.count));
            _presentingUsers = _contacts.mutableCopy;
            [_contactsTable reloadData];
        } failure:^(NSError * _Nonnull error) {
            NSLog(@"search users err %@",error);
        }];
    }
}

#pragma mark - Interface Methods

- (NSArray *)leftBarButtonItems
{
    return _cancelBBI?@[_cancelBBI]:@[];
}

- (NSArray *)rightBarButtonItems
{
    return _createBBI?@[_createBBI]:@[];
}
- (NSString *)titleString
{
    return @"Contacts";
}


- (void)shouldCreateChatWithSelectedUsers:(NSArray* <MMUser*>)users;
{
    NSLog(@"Activated didPressRightBarButtonItem. You should override this method to catch this interaction.");
}

#pragma mark - Life Cycle

#pragma mark UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _presentingUsers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = @"contactCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        
        cell.imageView.image = [UIImage imageNamed:@"user_default"];
    }
    MMUser *user = _presentingUsers[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@%@%@",
                           user.firstName.length?user.firstName:@"",
                           user.lastName.length?@"":@"",
                           user.lastName.length?user.lastName:@""];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:user.avatarURL];
        if (data.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.imageView.image = [UIImage imageWithData:data];
            });
        }
    });
    
    return cell;
}


#pragma mark Actions

- (IBAction)rightBtnPress:(UIBarButtonItem*)sender
{
    NSArray *indexPaths = [_contactsTable indexPathsForSelectedRows];
    
    NSMutableArray *selectedUsers = @[].mutableCopy;
    for (NSIndexPath *path in indexPaths) {
        [selectedUsers addObject:_presentingUsers[path.row]];
    }
    
    [self shouldCreateChatWithSelectedUsers:selectedUsers];
}

- (IBAction)leftBtnPress:(UIBarButtonItem*)sender
{
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (self.navigationController) {
        if (self.navigationController.presentingViewController) {
            if (self.navigationController.viewControllers.count == 1) {
                
                [self.navigationController dismissViewControllerAnimated:YES completion:nil];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
                
            }
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

@end