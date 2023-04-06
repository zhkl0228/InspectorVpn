//
//  ViewController.m
//  InspectorVpn
//
//  Created by Banny on 2023/4/5.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UISwitch *toggle;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        self->vpnManager = [managers firstObject];
        
        if(self->vpnManager) {
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
            [self.toggle setEnabled: YES];
            [self.toggle setOn: NO];

            [self.spinner stopAnimating];
            [self.statusLabel setText: @"Invalid"];
            break;
        case NEVPNStatusDisconnected:
            [self.toggle setEnabled: YES];
            [self.toggle setOn: NO];

            [self.spinner stopAnimating];
            [self.statusLabel setText: @"Disconnected"];
            break;
        case NEVPNStatusConnecting:
            [self.toggle setEnabled: NO];
            [self.toggle setOn: YES];

            [self.spinner startAnimating];
            [self.statusLabel setText: @"Connecting..."];
            break;
        case NEVPNStatusConnected:
            [self.toggle setEnabled: YES];
            [self.toggle setOn: YES];

            [self.spinner stopAnimating];
            [self.statusLabel setText: @"Connected"];
            break;
        case NEVPNStatusDisconnecting:
            [self.toggle setEnabled: NO];
            
            [self.spinner startAnimating];
            [self.statusLabel setText: @"Disconnecting..."];
            break;
        default:
            NSLog(@"vpnStatusDidChanged notification=%@, status=%ld", notification, (long)status);
            break;
    }
}

- (void) toggle: (UISwitch *) sender {
    if([sender isOn]) {
        [self installProfile];
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
            BOOL started = [[self->vpnManager connection] startVPNTunnelAndReturnError:nil];
            NSLog(@"saveToPreferencesWithCompletionHandler started=%d", started);
        } else {
            [self installProfile];
        }
    }];
}

-(void) installProfile {
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
