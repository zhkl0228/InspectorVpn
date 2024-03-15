//
//  PacketTunnelProvider.h
//  InspectorVpnTunnel
//
//  Created by Banny on 2023/4/5.
//

#import <NetworkExtension/NetworkExtension.h>
#import "GCDAsyncSocket.h"

#define TAG_READ_SIZE 0
#define TAG_READ_PACKET 1
#define TAG_WRITE_PACKET 2
#define VPN_MAGIC 0xe

@interface PacketTunnelProvider : NEPacketTunnelProvider <GCDAsyncSocketDelegate> {
    GCDAsyncSocket *socket;
    BOOL canStop;
    void (^completionHandler)(NSError *);
}
@end
