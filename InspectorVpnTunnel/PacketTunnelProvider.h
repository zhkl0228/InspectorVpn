//
//  PacketTunnelProvider.h
//  InspectorVpnTunnel
//
//  Created by Banny on 2023/4/5.
//

#import <NetworkExtension/NetworkExtension.h>
#import "GCDAsyncSocket.h"

@interface PacketTunnelProvider : NEPacketTunnelProvider <GCDAsyncSocketDelegate> {
    GCDAsyncSocket *socket;
    BOOL canStop;
}
@end
