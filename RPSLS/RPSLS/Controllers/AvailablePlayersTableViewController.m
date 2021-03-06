/*
 * Copyright (c) 2015 Magnet Systems, Inc.
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

#import "AvailablePlayersTableViewController.h"
#import "RPSLSConstants.h"
#import "RPSLSUserStats.h"
#import "RPSLSUser.h"
#import "RPSLSMessageTypes.h"
#import "RPSLSUtils.h"
#import "GameViewController.h"
#import "AvailablePlayersTableViewCell.h"
#import "MMXMessage+RPSLS.h"
@import MagnetMax;

@interface AvailablePlayersTableViewController ()

@property (nonatomic, strong) RPSLSUser * playerBotUser;
@property (nonatomic, copy) NSArray * availablePlayersList;
@property (nonatomic, assign) BOOL inGame;

- (void)goToLoginScreen;

@end

@implementation AvailablePlayersTableViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.availablePlayersList = @[];

	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
 	[refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
 	[self setRefreshControl:refreshControl];

}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	self.title = @"Available Players";

	self.inGame = NO;

    [self postAvailabilityStatusAs:YES];
	
	[MMUser usersWithUserNames:@[@"player_bot"] success:^(NSArray *users) {
		if (users && users.count) {
			RPSLSUser * user = [RPSLSUser userWithUserObject:users.firstObject stats:[RPSLSUserStats new]];
			user.isAvailable = YES;
			self.playerBotUser = user;
		}
		[self collectListOfAvailablePlayers];
	} failure:^(NSError * error) {
		[self collectListOfAvailablePlayers];
	}];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMessage:)
                                                 name:MMXDidReceiveMessageNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didDisconnect:)
                                                 name:MMUserDidReceiveAuthenticationChallengeNotification
                                               object:nil];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(handleResignActive)
												 name: UIApplicationWillResignActiveNotification
											   object: nil];
	
}

- (void)handleResignActive {
	[self postAvailabilityStatusAs:NO];
	[self goToLoginScreen];
}


- (void)didReceiveMessage:(NSNotification *)notification {
    MMXMessage *message = notification.userInfo[MMXMessageKey];
    switch (message.messageType) {

        case MMXMessageTypeDefault:{
            /*
             *  Checking the incoming message and sending a confirmation if necessary.
             */
            if ([message isTimelyMessage]) {
                [self handleMessage:message];
            }
            break;
        }
        case MMXMessageTypeChannel:{
            /*
             *  Checking to see if the message is from the availability topic and ignoring all others
             */
            if ([message.channel.name isEqualToString:kPostStatus_ChannelName]) {
                [self updateListWithMessage:message];
            }
            break;
        }
    };
}

- (void)didDisconnect:(NSNotification *)notification {
    
    // Indicate that you are not ready to receive messages now!
    [MMX stop];
    
    [self goToLoginScreen];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:(BOOL)animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Availability

- (void)postAvailabilityStatusAs:(BOOL)available {
	/*
	 *  Publishing our availability message. In this case I do not need to do anything on success.
	 */
	[MMXChannel channelForName:kPostStatus_ChannelName isPublic:YES success:^(MMXChannel *channel) {
		[channel publish:[RPSLSUtils availablilityMessageContent:available] success:nil failure:^(NSError *error) {
			[[MMXLogger sharedLogger] error:@"channelForName error= %@",error];
		}];
	} failure:^(NSError *error) {
		[[MMXLogger sharedLogger] error:@"channelForName error= %@",error];
	}];
}

#pragma mark - Request Available Players

- (void)collectListOfAvailablePlayers {
	
	[self refreshAvailablePlayersWithMessages:nil];
	[MMXChannel channelForName:kPostStatus_ChannelName isPublic:YES success:^(MMXChannel *channel) {
		[channel messagesBetweenStartDate:[NSDate dateWithTimeIntervalSinceNow:kAvailableTimeFrame]
								  endDate:nil
									limit:100
								   offset:0
								ascending:NO
								  success:^(int totalCount, NSArray *messages) {
									  
									  [self refreshAvailablePlayersWithMessages:messages];
									  
								  } failure:^(NSError *error) {
									  
									  /*
									   *  Logging an error.
									   */
									  [[MMXLogger sharedLogger] error:@"collectListOfAvailablePlayers error = %@",error];
									  
								  }];
	} failure:^(NSError *error) {
		[[MMXLogger sharedLogger] error:@"channelForName error= %@",error];
	}];
}

#pragma mark - Available Players

- (void)refreshAvailablePlayersWithMessages:(NSArray *)messages {
	NSMutableArray *tempArray = [NSMutableArray array];
	if (self.playerBotUser) {
		[tempArray addObject:self.playerBotUser];
	}
	for (MMXMessage *msg in messages) {
		RPSLSUser * user = [RPSLSUser availablePlayerFromMessage:msg];
		[tempArray addObject:user];
	}
	
	if (tempArray.count) {
		NSOrderedSet * set = [NSOrderedSet orderedSetWithArray:tempArray];
		NSArray *unique = set.array;
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(isAvailable == YES) AND (messageUserObject != %@)",[RPSLSUser me].messageUserObject];
		NSArray *filtered  = [unique filteredArrayUsingPredicate:predicate];
		
		self.availablePlayersList = filtered;
	} else {
		self.availablePlayersList = @[];;
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.tableView reloadData];
		if (self.refreshControl.isRefreshing) {
			[self.refreshControl endRefreshing];
		}
	});
}

- (void)updateListWithMessage:(MMXMessage *)message {
	RPSLSUser * user = [RPSLSUser availablePlayerFromMessage:message];
	
	if (![user isEqual:[RPSLSUser me]]) {
		if (!user.isAvailable) {
			
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"messageUserObject != %@",user.messageUserObject];
			NSMutableArray *filtered  = [self.availablePlayersList filteredArrayUsingPredicate:predicate].mutableCopy;
			self.availablePlayersList = filtered.copy;
			
		} else if (NSNotFound == [self.availablePlayersList indexOfObject:user]){
			
			self.availablePlayersList = [@[user] arrayByAddingObjectsFromArray:self.availablePlayersList];
		
		}
		[self.tableView reloadData];
	}
}

#pragma mark - Refresh

- (void)refresh {
	
	self.availablePlayersList = @[];
	[self.tableView reloadData];
	[self.refreshControl beginRefreshing];
	[self collectListOfAvailablePlayers];
	
}

#pragma mark - Invite

- (void)sendInviteTo:(MMUser *)user {

    NSDictionary *messageContent = @{kMessageKey_Username : [RPSLSUser me].messageUserObject.userName,
            kMessageKey_Timestamp : [RPSLSUtils timestamp],
            kMessageKey_Type : kMessageTypeValue_Invite,
            kMessageKey_GameID : [AvailablePlayersTableViewController newGameID],
            kMessageKey_Wins : [@([RPSLSUser me].stats.wins) stringValue],
            kMessageKey_Losses : [@([RPSLSUser me].stats.losses) stringValue],
            kMessageKey_Ties : [@([RPSLSUser me].stats.ties) stringValue]};

    MMXMessage *message = [MMXMessage messageToRecipients:[NSSet setWithArray:@[user]] messageContent:messageContent];

    [message sendWithSuccess:^(NSSet *invalidUsers) {
		NSLog(@"sendWithSuccess Success\nInvalid Users = %@",invalidUsers);
	} failure:^(NSError *error) {
		NSLog(@"sendWithSuccess Failure Error = %@",error);
	}];
}

- (void)replyToInvite:(MMXMessage *)invite accept:(BOOL)accept {

    NSDictionary *messageContent = @{kMessageKey_Username	:[RPSLSUser me].messageUserObject.userName,
									 kMessageKey_Timestamp	:[RPSLSUtils timestamp],
									 kMessageKey_Type		:kMessageTypeValue_Accept,
									 kMessageKey_Result		: accept ? @"true" : @"false",
									 kMessageKey_GameID		:invite.messageContent[kMessageKey_GameID],
									 kMessageKey_Wins		:[@([RPSLSUser me].stats.wins) stringValue],
									 kMessageKey_Losses		:[@([RPSLSUser me].stats.losses) stringValue],
									 kMessageKey_Ties		:[@([RPSLSUser me].stats.ties) stringValue]};

    [invite replyWithContent:messageContent success:^(NSSet *invalidUsers) {
	} failure:^(NSError *error) {
	}];

    if (accept) {
        self.inGame = YES;
        [self startGame:invite];
    }
}

- (void)startGame:(MMXMessage *)message {
	RPSLSUser * user = [RPSLSUser playerFromInvite:message];
	GameViewController* game = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:NSStringFromClass([GameViewController class])];
	[game setupGameWithID:message.messageContent[kMessageKey_GameID] opponent:user];

	/*
	 *  Setting GameViewController as the delegate to receive the MMXClientDelegate callbacks.
	 */
	[self presentViewController:game animated:YES completion:nil];
}


#pragma mark - Message Logic

- (void)handleMessage:(MMXMessage *)message {
	RPSLSMessageType type = [self typeForMessage:message];
	switch (type) {
		case RPSLSMessageTypeUnknown:
			break;
		case RPSLSMessageTypeInvite:
			if (message.messageContent[kMessageKey_Username]) {
				[self showInviteAlertForUser:message.messageContent[kMessageKey_Username] invite:message];
			}
			break;
		case RPSLSMessageTypeAccept:
            if ([RPSLSUtils isTrue:message.messageContent[kMessageKey_Result]]) {
                self.inGame = YES;
                [self startGame:message];
            }
			break;
		case RPSLSMessageTypeChoice:
			break;
		default:
			break;
	}
}

- (RPSLSMessageType)typeForMessage:(MMXMessage *)message {

	/*
	 *  Extracting information from the MMXInboundMessage metaData property.
	 */
	if (message == nil || message.messageContent == nil || message.messageContent[kMessageKey_Type] == nil || [message.messageContent[kMessageKey_Type] isEqualToString:@""]) {
		return RPSLSMessageTypeUnknown;
	}
	if ([message.messageContent[kMessageKey_Type] isEqualToString:kMessageTypeValue_Invite]) {
		return RPSLSMessageTypeInvite;
	}
	if ([message.messageContent[kMessageKey_Type] isEqualToString:kMessageTypeValue_Accept]) {
		return RPSLSMessageTypeAccept;
	}
	if ([message.messageContent[kMessageKey_Type] isEqualToString:kMessageTypeValue_Choice]) {
		return RPSLSMessageTypeChoice;
	}
	return 0;
}

#pragma mark - Invite Alert View

- (void)showInviteAlertForUser:(NSString *)username invite:(MMXMessage *)invite {
	UIAlertController *alertController = [UIAlertController
										  alertControllerWithTitle:@"Invitation"
										  message:[NSString stringWithFormat:@"You received an invitation from %@",username]
										  preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction *acceptAction = [UIAlertAction
								   actionWithTitle:NSLocalizedString(kMessageResultValue_Accept, @"Accept action")
								   style:UIAlertActionStyleDefault
								   handler:^(UIAlertAction *action)
								   {
									   [self replyToInvite:invite accept:YES];
								   }];
	UIAlertAction *declineAction = [UIAlertAction
								 actionWithTitle:NSLocalizedString(@"Decline", @"Decline action")
								 style:UIAlertActionStyleDefault
								 handler:^(UIAlertAction *action)
								 {
									 [self replyToInvite:invite accept:NO];
								 }];
	
	[alertController addAction:acceptAction];
	[alertController addAction:declineAction];
	[self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - TableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	RPSLSUser * user = self.availablePlayersList[indexPath.row];
	AvailablePlayersTableViewCell *cell = (AvailablePlayersTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
	[cell showSent];
	[cell setSelected:NO];
	[self sendInviteTo:user.messageUserObject];
}

#pragma mark - TableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.availablePlayersList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"AvailablePlayersTableViewCell";
	
	AvailablePlayersTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (!cell) {
		cell = [[AvailablePlayersTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
	}
	RPSLSUser * user = self.availablePlayersList[indexPath.row];
	[cell setUserForCell:user];
	
	return cell;
}

#pragma mark - Utils

+ (NSString *)newGameID {
	return [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
}

#pragma mark - Private implementation

- (void)goToLoginScreen {
	[self.navigationController popToRootViewControllerAnimated:YES];
}



@end
