//
//  HMClientVersionCheck.h
//  AFNetworking
//
//  Created by 唐嗣成 on 2018/6/1.
//

#import <Foundation/Foundation.h>
typedef void (^hmClientCheckResultCallBack)(BOOL check);
@interface HMClientVersionCheck : NSObject

-(BOOL) checkClientVersionByBlock:(hmClientCheckResultCallBack)callBack;
@end
