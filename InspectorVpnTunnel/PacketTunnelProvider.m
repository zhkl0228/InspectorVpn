//
//  PacketTunnelProvider.m
//  InspectorVpnTunnel
//
//  Created by Banny on 2023/4/5.
//

#import "PacketTunnelProvider.h"
#import "NSMutableData+Inspector.h"

@implementation PacketTunnelProvider

- (void) startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *) self.protocolConfiguration;
    NSDictionary *conf = [protocol providerConfiguration];
    NSString *host = [conf valueForKey: @"host"];
    NSString *port = [conf valueForKey: @"port"];
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
        }
        
        [strongSelf connectSocket: completionHandler: host : (uint16_t) [port intValue]];
    }];
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [sock readDataToLength:2 withTimeout:-1 tag:0];
    NSLog(@"didConnectToHost=%@, port=%d", host, port);
    self->canStop = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while(!self->canStop) {
            [self.packetFlow readPacketObjectsWithCompletionHandler:^(NSArray<NEPacket *> * _Nonnull packets) {
                NSMutableData *data = [NSMutableData data];
                for(NEPacket *packet in packets) {
                    NSData *ip = [packet data];
                    [data writeShort: (uint16_t) [ip length]];
                    [data appendData: ip];
                }
                NSLog(@"readPackets: %@, data=%@", packets, data);
                [self->socket writeData: data withTimeout:-1 tag: 0x2];
            }];
        }
        NSLog(@"Stop read packets");
    });
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"didReadData sock=%@, data=%@, tag=%lu", sock, data, tag);
    
    if(tag == 0) {
        const uint8_t *bytes = [data bytes];
        uint16_t size = (bytes[0] << 8) | bytes[1];
        NSLog(@"didReadData length=0x%x", size);
        [sock readDataToLength:size withTimeout:-1 tag:1];
    } else if(tag == 1) {
        [self.packetFlow writePackets:[NSArray arrayWithObject: data] withProtocols:[NSArray arrayWithObject: [NSNumber numberWithInt:AF_INET]]];
        [sock readDataToLength:2 withTimeout:-1 tag:0];
    }
}

- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"didWriteDataWithTag sock=%@, tag=%ld", sock, tag);
}

- (void) connectSocket: (void (^)(NSError * _Nullable))completionHandler : (NSString *) host : (uint16_t) port {
    self->socket = [[GCDAsyncSocket alloc] initWithDelegate: self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
    [self->socket enableBackgroundingOnSocket];
    [self->socket setIPv6Enabled: NO];
    
    NSError *error = nil;
    if(![self->socket connectToHost:host onPort:port error:&error]) {
        completionHandler(error);
    } else {
        completionHandler(nil);
    }
}

- (void) stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    NSLog(@"stopTunnelWithReason=%ld, handler=%@", (long)reason, completionHandler);
    self->canStop = YES;
    [self->socket disconnect];
    self->socket = nil;
    completionHandler();
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"socketDidDisconnect sock=%@, err=%@", sock, err);
    [self cancelTunnelWithError: err];
}

@end
