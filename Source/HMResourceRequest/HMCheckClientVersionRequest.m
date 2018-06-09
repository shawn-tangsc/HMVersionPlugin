//
//  HMCheckClientVersionRequest.m
//  homeApp
//
//  Created by 唐嗣成 on 2018/3/18.
//  Copyright © 2018年 benmu. All rights reserved.
//

#import "HMCheckClientVersionRequest.h"
#import <BMBaseLibrary/BMConfigManager.h>


@interface HMCheckClientVersionRequest()

@property (nonatomic, readwrite) NSString * appName;

@property (nonatomic, readwrite) NSString * appVersion;


@end
@implementation HMCheckClientVersionRequest

-(instancetype) initWithAppName:(NSString *)appName appVersion:(NSString *)appVersion{
    if(self = [super init]){
        _appName = appName;
        _appVersion = appVersion;
    }
    return self;
}

- (NSString *) requestURLPath{
    return [self requestUrl];
}

-(NSString *)requestUrl{
//    NSString * url =[NSString stringWithFormat:@"%@/app/checkClientVersion",[BMConfigManager shareInstance].platform.url.request] ;
//    return url;
    return [BMConfigManager shareInstance].platform.url.clientUpdate;
}

-(id)requestArgument{
    return @{
             @"appName":_appName,
             @"clientType": @"iOS",
             @"clientVersion":_appVersion
             };
}
@end
