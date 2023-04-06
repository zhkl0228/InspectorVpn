//
//  PacketTunnelProvider.m
//  InspectorVpnTunnel
//
//  Created by Banny on 2023/4/5.
//

#import "PacketTunnelProvider.h"

@implementation PacketTunnelProvider

- (void) startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSLog(@"startTunnelWithOptions=%@, handler=%@", options, completionHandler);
    
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress: @"127.0.0.1"];
    
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:[NSArray arrayWithObject: @"10.1.10.1"] subnetMasks: [NSArray arrayWithObject: @"255.255.255.0"]];
    NEIPv4Route *defaultRoute = [NEIPv4Route defaultRoute];
    [ipv4Settings setIncludedRoutes: [NSArray arrayWithObject: defaultRoute]];
    [ipv4Settings setExcludedRoutes: [NSArray arrayWithObjects:
                                      [[NEIPv4Route alloc] initWithDestinationAddress:@"10.0.0.0" subnetMask:@"255.0.0.0"],
                                      [[NEIPv4Route alloc] initWithDestinationAddress:@"127.0.0.0" subnetMask:@"255.0.0.0"],
                                      [[NEIPv4Route alloc] initWithDestinationAddress:@"192.168.0.0" subnetMask:@"255.255.0.0"],
                                      nil]];
    [settings setIPv4Settings: ipv4Settings];
    
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers: [NSArray arrayWithObjects: @"8.8.8.8", @"8.8.4.4", nil]];
    [dnsSettings setMatchDomains: [NSArray arrayWithObject: @""]];
    [settings setDNSSettings: dnsSettings];
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        completionHandler(error);
        NSLog(@"setTunnelNetworkSettings error=%@", error);
    }];
}

- (void) stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    NSLog(@"stopTunnelWithReason=%ld, handler=%@", (long)reason, completionHandler);
    completionHandler();
}

@end
