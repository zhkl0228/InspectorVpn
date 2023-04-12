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
        NSLog(@"setTunnelNetworkSettings error=%@, appRules=%@, routingMethod=%ld", error, [strongSelf appRules], (long)[strongSelf routingMethod]);
        if(error) {
            completionHandler(error);
        } else {
            [strongSelf connectSocket: completionHandler: host : (uint16_t) [port intValue]];
        }
    }];
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if(self->completionHandler) {
        self->completionHandler(nil);
        self->completionHandler = nil;
    }
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
                    NEFlowMetaData *metaData = [packet metadata];
                    NSLog(@"readPacket: packet=%@, metaData=%@", packet, metaData);
                }
                [self->socket writeData: data withTimeout:-1 tag: TAG_WRITE_PACKET];
            }];
        }
        NSLog(@"Stop read packets");
    });
    [sock readDataToLength:2 withTimeout:-1 tag:TAG_READ_SIZE];
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"didReadData sock=%@, data=%@, tag=%lu", sock, data, tag);
    
    if(tag == TAG_READ_SIZE) {
        const uint8_t *bytes = [data bytes];
        uint16_t size = (bytes[0] << 8) | bytes[1];
        NSLog(@"didReadData length=0x%x", size);
        [sock readDataToLength:size withTimeout:-1 tag:TAG_READ_PACKET];
    } else if(tag == TAG_READ_PACKET) {
        [self.packetFlow writePackets:[NSArray arrayWithObject: data] withProtocols:[NSArray arrayWithObject: [NSNumber numberWithInt:AF_INET]]];
        [sock readDataToLength:2 withTimeout:-1 tag:TAG_READ_SIZE];
    }
}

- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"didWriteDataWithTag sock=%@, tag=%ld", sock, tag);
}

- (void) connectSocket: (void (^)(NSError * _Nullable))completionHandler : (NSString *) host : (uint16_t) port {
    self->socket = [[GCDAsyncSocket alloc] initWithDelegate: self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
    [self->socket enableBackgroundingOnSocket];
    [self->socket setIPv6Enabled: NO];
    
    self->completionHandler = completionHandler;
    NSError *error = nil;
    if(![self->socket connectToHost:host onPort:port withTimeout:3 error:&error]) {
        completionHandler(error);
        self->completionHandler = nil;
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
    NSLog(@"socketDidDisconnect sock=%@, err=%@, completionHandler=%@", sock, err, self->completionHandler);
    if(self->completionHandler && err) {
        self->completionHandler(err);
        self->completionHandler = nil;
    } else {
        [self cancelTunnelWithError: err];
    }
}

@end
