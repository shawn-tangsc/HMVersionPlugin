//
//  HMVersionManager.m
//  AFNetworking
//
//  Created by 唐嗣成 on 2018/6/11.
//

#import "HMVersionManager.h"
#import "Reachability.h"
#import "HMClientVersionCheck.h"
#import "HMCheckJsVersionRequest.h"
#import "HMUpdateBundlejsRequest.h"
#import "BMResourceManager.h"
#import "BMConfigManager.h"
#import "SVProgressHUD.h"
#import "NSData+bsdiff.h"
#import "BMResourceCheck.h"
#import "BMMediatorManager.h"
#import "BMResourceManager.h"

#define JS_VERSION @"jsVersion"

static NSString * bundle = @"bundle";

static NSString * zip = @"zip";

typedef NS_ENUM(NSUInteger, BMResourceCheckUpdateCode) {
    HMResourceCheckUpdateSuccess= 0,  //查询成功
    HMResourceCheckUpdateFail = 4001,
    HMResourceCheckUpdateLasted = 4000
};

@interface HMVersionManager()


@property (nonatomic, copy) NSString *updateBundleJsUrl;
@property (nonatomic,weak)HMUpdateBundlejsRequest * updateBundleRequest;
@end


@implementation HMVersionManager

+ (instancetype) sharedInstance{
    static HMVersionManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[HMVersionManager alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /** app 即将进入后台的通知 */
        //        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

/** app即将进入后台的通知 */
- (void)appWillResignActive
{
    //    if (self.updateBundleRequest) {
    //        [self.updateBundleRequest saveIncompleteDownloadTempData];
    //    }
}

/** app进入激活状态 */
- (void)appDidBecomeActive
{
    /** 检查js更新 */
    /** 只有在wifi状态下，才去判断激活*/
    Reachability * reachabilityManager = [Reachability reachabilityForInternetConnection];
    if ([reachabilityManager currentReachabilityStatus] == ReachableViaWiFi) {
        HMClientVersionCheck * cli = [[HMClientVersionCheck alloc] init];
        [cli checkClientVersionByBlock:^(BOOL check) {
            if(!check){
                [self checkNewVersion:YES];
            }
        }];
        /** 检查js更新 */
        
    }else {
        WXLog(@"不在wifi内");
    }
    
}

/** 检查js资源文件是否有新版本 */
- (void)checkNewVersion:(BOOL)isDiff
{
    if (![BMConfigManager shareInstance].platform.url.bundleUpdate.length) return;
    
    NSDictionary * currentConfig = [[BMResourceManager sharedInstance] loadConfigData:K_JS_VERSION_PATH];
    //    WXLogInfo(@"currentConfig is %@",currentConfig);
    
    //    NSString * appName = currentConfig[APP_NAME_KEY]?currentConfig[APP_NAME_KEY]:@"app-benmu-health";
    NSString * jsVersion = currentConfig[JS_VERSION]?currentConfig[JS_VERSION]:@"";
    
    
    
    __weak typeof(self) weakSelf = self;
    
    /* 线上js版本 */
    HMCheckJsVersionRequest *checkVersionApi = [[HMCheckJsVersionRequest alloc] initWithAppName:[BMConfigManager shareInstance].platform.appName appVersion:K_APP_VERSION jsVersion:jsVersion isDiff:isDiff];
    
    
    
    [checkVersionApi startWithCompletionBlockWithSuccess:^(__kindof YTKBaseRequest * _Nonnull request) {
        
        WXLogInfo(@"%@ Request_Success >>>>>>>>>>>>>>>>:%@",NSStringFromClass([self class]),request.requestTask.originalRequest);
        
        NSDictionary *result = [request responseObject];
        NSString *resCode = [NSString stringWithFormat:@"%@",result[@"resCode"]];
        NSDictionary *data = result[@"data"];
        
        if ([resCode intValue] == HMResourceCheckUpdateSuccess && data) {
            
            // 有更新版本
            [weakSelf downloadRemoteJSResource:data];
            
        }
        else if([resCode intValue] == HMResourceCheckUpdateFail){
            
            // 检测失败无对应版本
            
        }else if ([resCode intValue] == HMResourceCheckUpdateLasted){
            
            // 已是最新版本
        }
        else{
            
            
        }
        
        WXLogInfo(@"%@",result[@"msg"]);
        
    } failure:^(__kindof YTKBaseRequest * _Nonnull request) {
        
        WXLogError(@"%@ Request_Error >>>>>>>>>>>>>>>>:%@",NSStringFromClass([request class]),request.requestTask.originalRequest);
        
    }];
    
}
/* 下载远程js文件 */
- (void)downloadRemoteJSResource:(NSDictionary*)downloadDict
{
    
    NSString * urlString = downloadDict[@"path"];
    BOOL isDiff = [downloadDict[@"diff"] boolValue];
    
    if (urlString.length == 0) {
        return;
    }
    
    /** 判断 如果 self.updateBundleJsUrl 等于 urlString 则说明当前已存在下载任务 */
    if ([self.updateBundleJsUrl isEqualToString:urlString]) {
        return;
    }
    
    self.updateBundleJsUrl = urlString;
    
    __weak typeof(self) weakSelf = self;
    
    /* 下载最新版本 */
    HMUpdateBundlejsRequest *updateJsApi = [[HMUpdateBundlejsRequest alloc] initWithDownloadJSUrl:urlString];
    
    self.updateBundleRequest = updateJsApi;
    
    updateJsApi.resumableDownloadProgressBlock = ^(NSProgress *progress) {
        
        WXLogInfo(@"\n 下载进度>>>> 文件总大小：%lld 已下载：%lld",progress.totalUnitCount,progress.completedUnitCount);
        
#ifdef DEBUG
        [SVProgressHUD showProgress:((float)progress.completedUnitCount / (float)progress.totalUnitCount) status:@"js资源文件更新中..."];
#endif
        
    };
    [updateJsApi startWithCompletionBlockWithSuccess:^(__kindof YTKBaseRequest * _Nonnull request) {
        
        WXLogInfo(@"%@ 下载js文件成功 Request_URL>>>>>>>>>>>>>>>>:%@",NSStringFromClass([request class]),request.requestTask.originalRequest);
        
        [SVProgressHUD dismiss];
        
        /* 标记js文件缓存成功 */
        //判断是否是diff文件 如果是 需要bsdiff 如果不是 直接校验
        if (isDiff) {
            NSData * oldData = [NSData dataWithContentsOfFile:[K_JS_BUNDLE_PATH stringByAppendingFormat:@"/%@.%@",bundle,zip]];
            
            NSURL * url = [NSURL URLWithString:urlString];
            NSString * fileName = [url lastPathComponent];
            NSString * downloadPath = [K_JS_CACHE_PATH stringByAppendingFormat:@"/%@",fileName];
            
            
            
            NSData * patchData = [NSData dataWithContentsOfFile:downloadPath];
            NSLog(@"patchData is %lu",(unsigned long)patchData.length);
            
            
            NSData * newData = [NSData dataWithData:oldData andPatch:patchData];
            NSLog(@"newData is %lu",(unsigned long)newData.length);
            if (newData.length == 0) {
                NSLog(@"BSDIFF 数据失败 记录");
                
                [weakSelf checkNewVersion:NO];
                return;
            }
            
            
            NSString * newZipPath = [K_JS_CACHE_PATH stringByAppendingFormat:@"/%@.%@",bundle,zip];
            
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:newZipPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:newZipPath error:nil];
            }
            
            
            BOOL diffPathZip = [newData writeToFile:newZipPath atomically:YES];
            
            if (diffPathZip){
                WXLogInfo(@"DIFF 数据成功");
                [weakSelf checkDownloadZips:newZipPath downloadPath:downloadPath];
            }
        } else {
            WXLogInfo(@"解析全量包");
            
            
            
            NSString * newZipPath = [K_JS_CACHE_PATH stringByAppendingFormat:@"/%@.%@",bundle,zip];
            
            NSURL * url = [NSURL URLWithString:urlString];
            NSString * fileName = [url lastPathComponent];
            NSString * downloadPath = [K_JS_CACHE_PATH stringByAppendingFormat:@"/%@",fileName];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:newZipPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:newZipPath error:nil];
            }
            
            [[NSFileManager defaultManager] copyItemAtPath:downloadPath toPath:newZipPath error:nil];
            
            
            [weakSelf checkDownloadZips:newZipPath downloadPath:downloadPath];
        }
    } failure:^(__kindof YTKBaseRequest * _Nonnull request) {
        
        WXLogError(@"%@ Request_URL>>>>>>>>>>>>>>>>:%@",NSStringFromClass([request class]),request.requestTask.originalRequest);
        
#ifdef DEBUG
        [SVProgressHUD dismiss];
#endif
        
        /** 下载失败将之前记录的下载地址清除掉 */
        weakSelf.updateBundleJsUrl = nil;
        
        if (isDiff) {
            //如果diff 包下载失败 再次查询全量包 下载
            [weakSelf checkNewVersion:NO];
        }
    }];
}

#pragma mark 校验包
-(void)checkDownloadZips:(NSString*)zipPath downloadPath:(NSString*)downloadPath
{
    
    __weak typeof(self) weakSelf = self;
    WXLogInfo(@"校验开始");
    [BMResourceCheck checkLocalResourceByZipPath:zipPath result:^(BOOL check, NSDictionary *info) {
        WXLogInfo(@"校验结束");
        
        [weakSelf cleanAndSaveData:info zipPath:downloadPath pagesPath:zipPath check:check];
    }];
}

-(void)cleanAndSaveData:(NSDictionary*)dict zipPath:(NSString*)zipPath  pagesPath:(NSString*)pagesPath check:(BOOL)check
{
    //1.删除下载的patch包
    if ([[NSFileManager defaultManager] fileExistsAtPath:zipPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];
    }
    
    
    //2.删除校验的临时目录 check
    if ([[NSFileManager defaultManager] fileExistsAtPath:[K_JS_CACHE_PATH stringByAppendingPathComponent:@"check"]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[K_JS_CACHE_PATH stringByAppendingPathComponent:@"check"] error:nil];
    }
    
    //3.根据校验结果 分别处理事件
    if (check) {
        //写入config文件
        if ([dict isKindOfClass:[NSDictionary class]]) {
            
            NSData * configData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
            if (configData.length > 0) {
                
                BOOL writeSuccess = [configData writeToFile:K_JS_CACHE_VERSION_PATH atomically:YES];
                if (writeSuccess) {
                    WXLogInfo(@"写入配置文件成功");
                    [BMResourceManager sharedInstance].bmWidgetJs = nil;
                    [[BMMediatorManager shareInstance] showJsResourceUpdatedAlert];
                    
                }
            }
        }
    }
    else{
        
#ifdef DEBUG
        [SVProgressHUD showInfoWithStatus:@"js资源文件更新完毕但是校验失败，请程序员哥哥查一下有啥Bug"];
#endif
        
        //校验失败  删除下载的全量包或者patch出的全量包
        if ([[NSFileManager defaultManager] fileExistsAtPath:pagesPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:pagesPath error:nil];
        }
    }
}

- (void)showJsResourceUpdatedAlert
{
    
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"更新提示" message:@"更新数据已准备就绪，完成更新获得完整功能体验。" preferredStyle:UIAlertControllerStyleAlert];
    
    //    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"稍后升级" style:UIAlertActionStyleDefault handler:nil];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"立即更新" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //        [[BMResourceManager sharedInstance] compareVersion];
        [[NSNotificationCenter defaultCenter] postNotificationName:K_BMAppReStartNotification object:nil];
    }];
    
    //    [alertVc addAction:cancelAction];
    [alertVc addAction:confirmAction];
    UIViewController *currentViewController = [BMMediatorManager shareInstance].currentViewController;
    [currentViewController presentViewController:alertVc animated:YES completion:nil];
}



@end
