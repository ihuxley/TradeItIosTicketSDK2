#import "TradeItRequest.h"

@interface TradeItOAuthLoginPopupUrlForTokenUpdateRequest : TradeItRequest

@property (copy, nonnull) NSString *apiKey;
@property (copy, nonnull) NSString *broker;
@property (copy, nonnull) NSString *userId;
@property (copy, nonnull) NSString *interAppAddressCallback;

- (_Nonnull id)initWithApiKey:(NSString * _Nonnull)apiKey
              broker:(NSString * _Nonnull)broker
              userId:(NSString * _Nonnull)userId
interAppAddressCallback:(NSString * _Nonnull)interAppAddressCallback;

@end
