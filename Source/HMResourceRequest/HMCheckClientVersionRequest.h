//
//  HMCheckClientVersionRequest.h
//  homeApp
//
//  Created by 唐嗣成 on 2018/3/18.
//  Copyright © 2018年 benmu. All rights reserved.
//

#import <BMBaseLibrary/BMBaseRequest.h>

@interface HMCheckClientVersionRequest : BMBaseRequest

- (instancetype) initWithAppName:(NSString *)appName appVersion:(NSString *)appVersion ;


@end
