//
//  ViewController.m
//  InspectorVpn
//
//  Created by Banny on 2023/4/5.
//

#import "ViewController.h"
#import "DataInput.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UISwitch *toggle;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *hostField;
@property (weak, nonatomic) IBOutlet UITextField *portField;
@end

@implementation ViewController

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    if([data length] >= 7 &&
       ([[DataInput alloc] init: [data bytes] length: (int) [data length]].readShort == 0x3)) {
        DataInput *input = [[DataInput alloc] init: [data bytes] length: (int) [data length]];
        NSString *vpn = [input readUTF];
        if([@"vpn" isEqualToString: vpn]) {
            uint16_t port = [input readShort] & 0xffffUL;
            
            NSString *ip = [GCDAsyncUdpSocket hostFromAddress: address];
            NSLog(@"didReceiveData ip=%@, port=%d", ip, port);
            
            NSString *ps = [NSString stringWithFormat: @"%d", port];
            if(self.hostField.isEditing || self.portField.isEditing || [self.portField.text isEqual: ps]) {
                return;
            }
            [self.hostField setText: ip];
            [self.portField setText: ps];
            [self vpnStatusDidChanged: nil];
        }
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NSLog(@"udpSocketDidClose sock=%@, error=%@", sock, error);
    
    self->udp = nil;
    [self tryStartUdpServer];
}

- (void)tryStartUdpServer {
    if(self->udp) {
        return;
    }
    self->udp = [[GCDAsyncUdpSocket alloc] initWithDelegate: self delegateQueue: dispatch_get_main_queue()];
    [self->udp setIPv6Enabled: NO];
    NSError *error = nil;
    if([self->udp enableBroadcast: YES error: &error]) {
        if([self->udp bindToPort: 20230 error: &error]) {
            if([self->udp beginReceiving: &error]) {
                NSLog(@"beginReceivingBroadcast");
            } else {
                NSLog(@"beginReceiving error=%@", error);
            }
        } else {
            NSLog(@"bindToPort error=%@", error);
        }
    } else {
        NSLog(@"enableBroadcast error=%@", error);
    }
}

- (void) textFieldDidBeginEditing:(UITextField *)textField {
    NSString *text = [textField text];
    NSLog(@"textFieldDidBeginEditing: %@", text);
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    NSString *text = [textField text];
    NSLog(@"textFieldDidEndEditing: %@", text);
    [self.toggle setEnabled: [self.hostField hasText] && [self.portField hasText]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.hostField setEnabled: YES];
    [self.portField setEnabled: YES];
    [self.hostField setDelegate: self];
    [self.portField setDelegate: self];
    
    [self tryStartUdpServer];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        self->vpnManager = [managers firstObject];
        
        if(self->vpnManager) {
            NETunnelProviderProtocol *providerProtocol = (NETunnelProviderProtocol *) [self->vpnManager protocolConfiguration];
            NSDictionary *conf = [providerProtocol providerConfiguration];
            [self.hostField setText: [conf valueForKey: @"host"]];
            [self.portField setText: [conf valueForKey: @"port"]];
            [self vpnStatusDidChanged: nil];
        } else {
            [self.hostField setText: @"192.168.1.1"];
            [self vpnStatusDidChanged: nil];
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver: self selector:@selector(vpnStatusDidChanged:) name:NEVPNStatusDidChangeNotification object:nil];
        
        NSLog(@"viewDidLoad vpnManager=%@, error=%@", self->vpnManager, error);
    }];
}

- (void) vpnStatusDidChanged: (NSNotification *) notification {
    NEVPNStatus status = [[vpnManager connection] status];
    switch (status) {
        case NEVPNStatusInvalid:
            [self.toggle setEnabled: [self.hostField hasText] && [self.portField hasText]];
            [self.toggle setOn: NO];
            [self.hostField setEnabled: NO];
            [self.portField setEnabled: NO];

            [self.spinner stopAnimating];
            if(self->vpnManager) {
                [self.statusLabel setText: @"Invalid"];
            }
            break;
        case NEVPNStatusDisconnected:
            [self.toggle setEnabled: [self.hostField hasText] && [self.portField hasText]];
            [self.toggle setOn: NO];
            [self.hostField setEnabled: YES];
            [self.portField setEnabled: YES];

            [self.spinner stopAnimating];
            [self.statusLabel setText: @"Disconnected"];
            break;
        case NEVPNStatusConnecting:
            [self.toggle setEnabled: NO];
            [self.toggle setOn: YES];
            [self.hostField setEnabled: NO];
            [self.portField setEnabled: NO];

            [self.spinner startAnimating];
            [self.statusLabel setText: @"Connecting..."];
            break;
        case NEVPNStatusConnected:
            [self.toggle setEnabled: YES];
            [self.toggle setOn: YES];
            [self.hostField setEnabled: NO];
            [self.portField setEnabled: NO];

            [self.spinner stopAnimating];
            [self.statusLabel setText: @"Connected"];
            break;
        case NEVPNStatusReasserting:
            [self.toggle setEnabled: NO];
            [self.hostField setEnabled: NO];
            [self.portField setEnabled: NO];

            [self.spinner startAnimating];
            [self.statusLabel setText: @"Reasserting.."];
            break;
        case NEVPNStatusDisconnecting:
            [self.toggle setEnabled: NO];
            [self.hostField setEnabled: NO];
            [self.portField setEnabled: NO];
            
            [self.spinner startAnimating];
            [self.statusLabel setText: @"Disconnecting"];
            break;
        default:
            NSLog(@"vpnStatusDidChanged notification=%@, status=%ld", notification, (long)status);
            break;
    }
}

- (void) toggle: (UISwitch *) sender {
    if([sender isOn]) {
        [self tryStartVpn];
    } else {
        [[vpnManager connection] stopVPNTunnel];
    }
}

-(void) startVpn: (BOOL) startImmediately {
    NETunnelProviderProtocol *tunnelProtocol = [NETunnelProviderProtocol new];
    [tunnelProtocol setServerAddress: @"localhost"];
    [tunnelProtocol setProviderBundleIdentifier: @"com.github.zhkl0228.inspector.vpn.extension"];
    [tunnelProtocol setDisconnectOnSleep: NO];
    if (@available(iOS 14.2, *)) {
        [tunnelProtocol setExcludeLocalNetworks: YES];
    }
    NSDictionary *conf = @{
        @"host" : [self.hostField text],
        @"port" : [self.portField text]
    };
    [tunnelProtocol setProviderConfiguration: conf];
    
    [self->vpnManager setProtocolConfiguration: tunnelProtocol];
    [self->vpnManager setLocalizedDescription: @"InspectorVpn"];
    [self->vpnManager setEnabled: YES];
    
    if(startImmediately) {
        NEVPNStatus status = [[self->vpnManager connection] status];
        if(status) {
            [self.toggle setOn: status == NEVPNStatusConnected];
        }
    }
    
    [self->vpnManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        NSLog(@"saveToPreferencesWithCompletionHandler error=%@", error);
        if(error) {
            return;
        }
        
        if(startImmediately) {
            NSError *error = nil;
            BOOL started = [[self->vpnManager connection] startVPNTunnelAndReturnError:&error];
            NSLog(@"saveToPreferencesWithCompletionHandler started=%d, error=%@, NETunnelProviderRoutingMethodSourceApplication=%ld", started, error, (long)NETunnelProviderRoutingMethodSourceApplication);
        } else {
            [self tryStartVpn];
        }
    }];
}

-(void) tryStartVpn {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        self->vpnManager = [managers firstObject];
        NSLog(@"loadAllFromPreferencesWithCompletionHandler managers=%@, error=%@, manager=%@", managers, error, self->vpnManager);
        if(error) {
            return;
        }
        if(self->vpnManager) {
            [self startVpn: YES];
        } else {
            self->vpnManager = [NETunnelProviderManager new];
            [self startVpn: NO];
        }
    }];
}


@end
