//
//  AppDelegate.h
//  InspectorVpn
//
//  Created by Banny on 2023/4/5.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@interface NSData (Hex)
-(NSString *) toHexString;
@end

@interface NSThread (Trace)
+(NSString *) WA_backtrace;
@end

