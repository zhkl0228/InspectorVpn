//
//  ViewController.h
//  InspectorVpn
//
//  Created by Banny on 2023/4/5.
//

#import <UIKit/UIKit.h>
#import <NetworkExtension/NetworkExtension.h>
#import "GCDAsyncUdpSocket.h"

@interface ViewController : UITableViewController <GCDAsyncUdpSocketDelegate> {
    NETunnelProviderManager *vpnManager;
    GCDAsyncUdpSocket *udp;
}

@end

