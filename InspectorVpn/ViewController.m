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
    
    vpnManager = [NETunnelProviderManager new];
    NSLog(@"viewDidLoad vpnManager=%@", vpnManager);
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver: self selector:@selector(vpnStatusDidChanged:) name:NEVPNStatusDidChangeNotification object:nil];
}

- (void) vpnStatusDidChanged: (NSNotification *) notification {
    NEVPNStatus status = [[vpnManager connection] status];
    NSLog(@"vpnStatusDidChanged notification=%@, status=%ld", notification, (long)status);
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"setUndefinedValue key=%@, value=%@", key, value);
}

- (void) toggle: (UISwitch *) sender {
    NSLog(@"toggle sender=%@", sender);
}


@end
