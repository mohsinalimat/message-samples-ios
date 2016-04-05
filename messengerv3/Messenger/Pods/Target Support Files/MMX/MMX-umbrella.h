#import <UIKit/UIKit.h>

#import "MagnetDelegate.h"
#import "MMUser+Addressable.h"
#import "MMXAsyncOperation.h"
#import "MMXChannel_Private.h"
#import "MMXConnectionOperation.h"
#import "MMXInternalAddress.h"
#import "MMXInvite_Private.h"
#import "MMXInviteResponse_Private.h"
#import "MMXLogInOperation.h"
#import "MMXMessage_Private.h"
#import "MMXWhitelistOperation.h"
#import "XMPPIQ+MMX.h"
#import "XMPPJID+MMX.h"
#import "MMXConfiguration.h"
#import "MMXConfigurationRegistry.h"
#import "MMXConstants.h"
#import "MMXErrorSeverityEnum.h"
#import "MMXAddressable.h"
#import "MMXEndpoint.h"
#import "MMXEndpoint_Private.h"
#import "MMXUserID.h"
#import "MMXUserID_Private.h"
#import "MMXInboundMessage.h"
#import "MMXInboundMessage_Private.h"
#import "MMXMessageOptions.h"
#import "MMXMessageOptions_Private.h"
#import "MMXOutboundMessage.h"
#import "MMXOutboundMessage_Private.h"
#import "MMXClient.h"
#import "MMXClient_Private.h"
#import "MMXInternalAck.h"
#import "MMXInternalMessageAdaptor.h"
#import "MMXInternalMessageAdaptor_Private.h"
#import "MMXIQResponse.h"
#import "MMXMessageStateQueryResponse.h"
#import "MMXMessageStateQueryResponse_Private.h"
#import "MMXQuery.h"
#import "MMXQuery_Private.h"
#import "MMXQueryFilter.h"
#import "MMXQueryFilter_Private.h"
#import "MMXInternal_Private.h"
#import "MMXOAuthPlatformAuthentication.h"
#import "MMXPrivacyManager.h"
#import "MMUser+Privacy.h"
#import "MMX.h"
#import "MMXChannel.h"
#import "MMXChannelDetailResponse.h"
#import "MMXInvite.h"
#import "MMXInviteResponse.h"
#import "MMXLogger.h"
#import "MMXMessage.h"
#import "MMXMessageTypes.h"
#import "MMXNotificationConstants.h"
#import "MMXPublishPermissionsEnum.h"
#import "MMXRemoteNotification.h"
#import "MMXAddSubscribersResponse.h"
#import "MMXChannelInfo.h"
#import "MMXChannelLookupKey.h"
#import "MMXChannelResponse.h"
#import "MMXChannelSummaryRequest.h"
#import "MMXItemPublisher.h"
#import "MMXMatchType.h"
#import "MMXPublisherType.h"
#import "MMXPubSubItemChannel.h"
#import "MMXPubSubPayload.h"
#import "MMXQueryChannel.h"
#import "MMXQueryChannelResponse.h"
#import "MMXRemoveSubscribersResponse.h"
#import "MMXSubscribeResponse.h"
#import "MMXUserInfo.h"
#import "MMXGeoLocationMessage.h"
#import "MMXGeoLocationMessage_Private.h"
#import "MMXPubSubFetchRequest.h"
#import "MMXPubSubFetchRequest_Private.h"
#import "MMXPubSubManager.h"
#import "MMXPubSubManager_Private.h"
#import "MMXPubSubMessage.h"
#import "MMXPubSubMessage_Private.h"
#import "MMXPubSubService.h"
#import "MMXTopic.h"
#import "MMXTopic_Private.h"
#import "MMXTopicListResponse.h"
#import "MMXWhitelistManager.h"
#import "MMXTopicQueryFilter.h"
#import "MMXTopicQueryFilter_Private.h"
#import "MMXTopicQueryResponse.h"
#import "MMXTopicQueryResponse_Private.h"
#import "MMXSubscriptionListResponse.h"
#import "MMXSubscriptionResponse.h"
#import "MMXSubscriptionResponse_Private.h"
#import "MMXTopicSubscribersResponse.h"
#import "MMXTopicSubscription.h"
#import "MMXTopicSubscription_Private.h"
#import "MMXTopicSummary.h"
#import "MMXTopicSummary_Private.h"
#import "MMXTopicSummaryRequestResponse.h"
#import "MMXUserProfile.h"
#import "MMXUserProfile_Private.h"
#import "MMXUserQueryFilter.h"
#import "MMXUserQueryFilter_Private.h"
#import "MMXUserQueryResponse.h"
#import "MMXUserQueryResponse_Private.h"
#import "MMXAssert.h"
#import "MMXiso8601DateTransformer.h"
#import "MMXMessageUtils.h"
#import "MMXTestingUtils.h"
#import "MMXUtils.h"

FOUNDATION_EXPORT double MMXVersionNumber;
FOUNDATION_EXPORT const unsigned char MMXVersionString[];

