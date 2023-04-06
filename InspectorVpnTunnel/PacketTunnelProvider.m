//
//  PacketTunnelProvider.m
//  InspectorVpnTunnel
//
//  Created by Banny on 2023/4/5.
//

#import "PacketTunnelProvider.h"
#import "GCDAsyncSocket.h"

@implementation PacketTunnelProvider

- (void) startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSString *host = [self.protocolConfiguration valueForKey: @"host"];
    NSString *port = [self.protocolConfiguration valueForKey: @"port"];
    NSLog(@"startTunnelWithOptions=%@, handler=%@, host=%@, port=%@", options, completionHandler, host, port);
    
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress: @"127.0.0.1"];
    
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:[NSArray arrayWithObject: @"10.1.10.1"] subnetMasks: [NSArray arrayWithObject: @"255.255.255.0"]];
    NEIPv4Route *defaultRoute = [NEIPv4Route defaultRoute];
    [ipv4Settings setIncludedRoutes: [NSArray arrayWithObject: defaultRoute]];
    [ipv4Settings setExcludedRoutes: [NSArray arrayWithObjects:
                                      [[NEIPv4Route alloc] initWithDestinationAddress:@"10.0.0.0" subnetMask:@"255.0.0.0"],
                                      [[NEIPv4Route alloc] initWithDestinationAddress:@"192.168.0.0" subnetMask:@"255.255.0.0"],
                                      nil]];
    [settings setIPv4Settings: ipv4Settings];
    
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers: [NSArray arrayWithObjects: @"8.8.8.8", @"8.8.4.4", nil]];
    [dnsSettings setMatchDomains: [NSArray arrayWithObject: @""]];
    [settings setDNSSettings: dnsSettings];
    
    __strong typeof(self) strongSelf = self;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        NSLog(@"setTunnelNetworkSettings error=%@", error);
        if(error) {
            completionHandler(error);
            return;
        } else {
            completionHandler(nil);
        }
        self->canStop = NO;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            while(strongSelf && !strongSelf->canStop) {
                [strongSelf readPackets];
            }
            NSLog(@"Stop read packets");
        });
    }];
}

- (void) readPackets {
    [self.packetFlow readPacketObjectsWithCompletionHandler:^(NSArray<NEPacket *> * _Nonnull packets) {
        NSLog(@"readPackets: %@", packets);
    }];
}

- (void) stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    NSLog(@"stopTunnelWithReason=%ld, handler=%@", (long)reason, completionHandler);
    self->canStop = YES;
    completionHandler();
}

@end
