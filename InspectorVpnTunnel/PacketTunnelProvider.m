//
//  PacketTunnelProvider.m
//  InspectorVpnTunnel
//
//  Created by Banny on 2023/4/5.
//

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import "PacketTunnelProvider.h"
#import "NSMutableData+Inspector.h"

@implementation PacketTunnelProvider

+(NSString *) getIPWithHostName:(const NSString *)hostName {
    @try {
        struct hostent *phot = gethostbyname([hostName UTF8String]);
        struct in_addr ip_addr;
        memcpy(&ip_addr, phot->h_addr_list[0], 4);
        char ip[20] = {0};
        inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));
        return [NSString stringWithUTF8String:ip];
    } @catch (NSException *exception) {
        return nil;
    }
}

- (void) startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *) self.protocolConfiguration;
    if (@available(iOS 14.0, *)) {
        [protocol setIncludeAllNetworks: YES];
    }
    if (@available(iOS 16.4, *)) {
        [protocol setExcludeAPNs: NO];
        [protocol setExcludeCellularServices: NO];
    }
    NSDictionary *conf = [protocol providerConfiguration];
    NSString *host = [conf valueForKey: @"host"];
    NSString *port = [conf valueForKey: @"port"];
    NSString *ip = [PacketTunnelProvider getIPWithHostName:host];
    NSLog(@"startTunnelWithOptions=%@, handler=%@, host=%@, port=%@, ip=%@", options, completionHandler, host, port, ip);
    
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress: @"127.0.0.1"];
    
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:[NSArray arrayWithObject: @"10.1.10.1"] subnetMasks: [NSArray arrayWithObject: @"255.255.255.0"]];
    NEIPv4Route *defaultRoute = [NEIPv4Route defaultRoute];
    [ipv4Settings setIncludedRoutes: [NSArray arrayWithObject: defaultRoute]];
    NSMutableArray *excludedRoutes = [NSMutableArray array];
    [excludedRoutes addObject:[[NEIPv4Route alloc] initWithDestinationAddress:@"10.0.0.0" subnetMask:@"255.0.0.0"]];
    [excludedRoutes addObject:[[NEIPv4Route alloc] initWithDestinationAddress:@"192.168.0.0" subnetMask:@"255.255.0.0"]];
    if(ip) {
        [excludedRoutes addObject:[[NEIPv4Route alloc] initWithDestinationAddress:ip subnetMask:@"255.255.255.255"]];
    }
    [ipv4Settings setExcludedRoutes: excludedRoutes];
    [settings setIPv4Settings: ipv4Settings];
    
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers: [NSArray arrayWithObjects: @"8.8.8.8", @"8.8.4.4", nil]];
    [dnsSettings setMatchDomains: [NSArray arrayWithObject: @""]];
    [settings setDNSSettings: dnsSettings];
    
    __strong typeof(self) strongSelf = self;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        NSLog(@"setTunnelNetworkSettings error=%@, routingMethod=%ld", error, (long)[strongSelf routingMethod]);
        if(error) {
            completionHandler(error);
        } else {
            [strongSelf connectSocket: completionHandler: host : (uint16_t) [port intValue]];
        }
    }];
}

- (void) readPackets {
    if(self->canStop) {
        NSLog(@"Stop read packets");
        return;
    }
    [self.packetFlow readPacketObjectsWithCompletionHandler:^(NSArray<NEPacket *> * _Nonnull packets) {
        NSMutableData *data = [NSMutableData data];
        for(NEPacket *packet in packets) {
            NSData *ip = [packet data];
            uint16_t length = (uint16_t) [ip length];
            uint8_t *ptr = (uint8_t *) [ip bytes];
            for(int i = 0; i < length; i++) {
                ptr[i] ^= VPN_MAGIC;
            }
            [data writeShort: length];
            [data appendData: [NSData dataWithBytes: ptr length:length]];
            NEFlowMetaData *metaData = [packet metadata];
            NSLog(@"readPacket: packet=%@, metaData=%@", packet, metaData);
        }
        [self->socket writeData: data withTimeout:-1 tag: TAG_WRITE_PACKET];
        [self readPackets];
    }];
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if(self->completionHandler) {
        self->completionHandler(nil);
        self->completionHandler = nil;
    }
    NSLog(@"didConnectToHost=%@, port=%d", host, port);
    NSString *config = @"/var/mobile/Library/inspector_vpn_config.txt";
    NSData *configData = [NSData dataWithContentsOfFile:config];
    uint8_t osType = 0x1;
    if(configData) {
        osType |= 0x80;
    }
    NSData *data = [NSData dataWithBytes: &osType length:1];
    [sock writeData: data withTimeout:-1 tag:TAG_WRITE_PACKET];
    if(configData) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSLocale *locale = [NSLocale currentLocale];
        [dict setValue: [locale localeIdentifier] forKey: @"locale"];
        [dict setValue: [locale objectForKey:NSLocaleLanguageCode] forKey: @"language"];
        [dict setValue: [locale objectForKey:NSLocaleCountryCode] forKey: @"country"];
        [dict setValue: [configData base64EncodedStringWithOptions:0] forKey: @"config"];
        NSData *json = [NSJSONSerialization dataWithJSONObject:dict options: 0 error:nil];
        NSMutableData *extraData = [NSMutableData data];
        [extraData writeShort: (int) [json length]];
        [extraData appendData: json];
        [sock writeData: extraData withTimeout:-1 tag: TAG_WRITE_PACKET];
    }
    self->canStop = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self readPackets];
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
        uint16_t length = (uint16_t) [data length];
        uint8_t *ptr = (uint8_t *) [data bytes];
        for(int i = 0; i < length; i++) {
            ptr[i] ^= VPN_MAGIC;
        }
        [self.packetFlow writePackets:[NSArray arrayWithObject: [NSData dataWithBytes: ptr length:length]] withProtocols:[NSArray arrayWithObject: [NSNumber numberWithInt:AF_INET]]];
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
