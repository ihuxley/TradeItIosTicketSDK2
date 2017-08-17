#import "TradeItResult.h"

@implementation TradeItResult

- (id)init {
    self = [super init];
    if (self) {
        self.token = nil;
        self.shortMessage = nil;
        self.longMessages = nil;
        self.status = nil;
    }
    return self;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"status=%@ token=%@ shortMessage=%@ longMessages%@",self.status, self.token, self.shortMessage, self.longMessages];
}

- (BOOL)isSuccessful {
    return [@"SUCCESS" isEqualToString:self.status];
}

- (BOOL)isError {
    return [@"ERROR" isEqualToString:self.status];
}

@end
