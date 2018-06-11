//
//  HMClientVersionCheck.m
//  AFNetworking
//
//  Created by 唐嗣成 on 2018/6/1.
//

#import "HMClientVersionCheck.h"
#import "HMCheckClientVersionRequest.h"
#import "BMMediatorManager.h"
#import "BMConfigManager.h"
@interface HMClientVersionCheck()
@property (nonatomic, strong)  UIAlertController *alertVc;
@property (strong, nonatomic) UIWindow *window;
@end

@implementation HMClientVersionCheck

#pragma mark lazy
- (UIWindow *)window {
    if (!_window) {
        UIApplication *app = [UIApplication sharedApplication];
        if ([app.delegate respondsToSelector:@selector(window)])
        {
            return [app.delegate window];
        }
        else
        {
            return [app keyWindow];
        }
    }
    return _window;
}

- (UIViewController *)getCurrentVC
{
    UIViewController *result = nil;
    
    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal)
    {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows)
        {
            if (tmpWin.windowLevel == UIWindowLevelNormal)
            {
                window = tmpWin;
                break;
            }
        }
    }
    
    UIView *frontView = [[window subviews] objectAtIndex:0];
    id nextResponder = [frontView nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]])
        result = nextResponder;
    else
        result = window.rootViewController;
    
    return result;
}


#pragma mark 大版本更新校验
-(void) checkClientVersionByBlock:(hmClientCheckResultCallBack)callBack{
    [self closeAlertVC];
    if (![BMConfigManager shareInstance].platform.url.clientUpdate.length){
        if(callBack){
            callBack(NO);
        }
        return;
    };
    
    HMCheckClientVersionRequest *checkClientVersion = [[HMCheckClientVersionRequest alloc]initWithAppName:@"home-app" appVersion:K_APP_VERSION];
    //    __weak typeof(self) weakSelf = self;
    [checkClientVersion startWithCompletionBlockWithSuccess:^(__kindof YTKBaseRequest * _Nonnull request) {
        WXLogInfo(@"%@ Request_Success >>>>>>>>>>>>>>>>:%@",NSStringFromClass([self class]),request.requestTask.originalRequest);
        NSDictionary *result = [request responseObject];
        NSLog(@"%@",result[@"data"]);
        NSString *resCode = result[@"resCode"];
        NSDictionary *data = result[@"data"];
        NSURL *url = [NSURL URLWithString:data[@"url"]];
        UIViewController *currentViewController = [self getCurrentVC];
        if([@"APP0003" isEqualToString:resCode]){//非强制更新
            self.alertVc = [UIAlertController alertControllerWithTitle:@"更新提示" message:data[@"description"] preferredStyle:UIAlertControllerStyleAlert];
            
//            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"稍后升级" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonull)];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"稍后升级" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if(callBack){
                    callBack(NO);
                }
            }];
            UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"立即升级" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                
                [[UIApplication sharedApplication] openURL:url];
                [self exitApplication];
                if(callBack){
                    callBack(YES);
                }
                //
            }];
            [self.alertVc addAction:cancelAction];
            [self.alertVc addAction:confirmAction];
//            UIViewController *currentViewController = [BMMediatorManager shareInstance].currentViewController;
            [currentViewController presentViewController:self.alertVc animated:YES completion:nil];
            
        }else if ([@"APP0002" isEqualToString:resCode]){//强制更新
            
            self.alertVc = [UIAlertController alertControllerWithTitle:@"更新提示" message:data[@"description"] preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"立即升级" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[UIApplication sharedApplication] openURL:url];
                [self exitApplication];
                if(callBack){
                    callBack(YES);
                }
            }];
            [self.alertVc addAction:confirmAction];
//            UIViewController *currentViewController = [BMMediatorManager shareInstance].currentViewController;
            [currentViewController presentViewController:self.alertVc animated:YES completion:nil];
        }else {
            if(callBack){
                callBack(NO);
            }
        }
    } failure:^(__kindof YTKBaseRequest * _Nonnull request) {
        if(callBack){
            callBack(NO);
        }
        WXLogError(@"%@ Request_Error >>>>>>>>>>>>>>>>:%@",NSStringFromClass([request class]),request.requestTask.originalRequest);
        
    }];
}
- (void)exitApplication {
    [UIView beginAnimations:@"exitApplication" context:nil];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationTransition:UIViewAnimationCurveEaseOut forView:self.window cache:NO];
    [UIView setAnimationDidStopSelector:@selector(animationFinished:finished:context:)];
    self.window.bounds = CGRectMake(0, 0, 0, 0);
    [UIView commitAnimations];
}

- (void)animationFinished:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if ([animationID compare:@"exitApplication"] == 0) {
        exit(0);
    }
}
-(void) checkClientVersionWithOutInitial {
    [self closeAlertVC];
//    [self checkClientVersion];
}

-(void)closeAlertVC{
    //
    if(self.alertVc!=nil){
        [self.alertVc dismissViewControllerAnimated:YES completion:nil];
        //        [self.alertVc removeFromParentViewController];
    }
}

@end
