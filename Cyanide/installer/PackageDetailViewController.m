//
//  PackageDetailViewController.m
//  Cyanide
//

#import "PackageDetailViewController.h"
#import "PackageQueue.h"
#import "../LogTextView.h"
#import "../PatreonAuth.h"
#import "../SettingsViewController.h"


static NSString * const kCallRecordingDisclosureAcceptedDefault =
    @"installer.callRecordingSoundDisclosureAccepted";

typedef NS_ENUM(NSInteger, PackageDetailSection) {
    PackageDetailSectionWarning = 0,
    PackageDetailSectionKnownIssues,
    PackageDetailSectionInfo,
    PackageDetailSectionAction,
    PackageDetailSectionSettings,
    PackageDetailSectionDescription,
    PackageDetailSectionCount,
};

@interface PackageDetailViewController ()
@property (nonatomic, strong) Package *package;
@property (nonatomic, copy)   NSArray<NSArray<NSString *> *> *infoRows;       // [[label, value], ...]
@property (nonatomic, copy)   NSArray<NSNumber *> *visibleSections;            // ordered PackageDetailSection values
@property (nonatomic, copy)   NSArray<NSDictionary<NSString *, NSString *> *> *settingsSummary;
@end

@implementation PackageDetailViewController

+ (void)presentCallRecordingDisclosureIfNeededFromViewController:(UIViewController *)presenter
                                                  confirmHandler:(dispatch_block_t)confirmHandler
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if ([d boolForKey:kCallRecordingDisclosureAcceptedDefault]) {
        if (confirmHandler) confirmHandler();
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Call Recording Disclosure"
                                            message:@"Silencing call-recording disclosure sounds may violate consent, notice, or privacy laws where you live or where the call participants are located. Only use this where you have permission and understand the rules that apply to you.\n\nCyanide modifies CallServices system files and keeps a backup when possible. You can restore the original sounds from this package."
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"I Understand, Silence"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *_) {
        [d setBool:YES forKey:kCallRecordingDisclosureAcceptedDefault];
        if (confirmHandler) confirmHandler();
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (BOOL)isOTAPackage
{
    return self.package.kind == PackageInstallKindOTA;
}

// "Manual-control" packages are stateless from the Installer's POV: the user
// just queues an install or uninstall intent and confirms. OTA and the
// NanoRegistry override both fit. The detail view shows a menu instead of a
// toggle button so the user sees both options.
- (BOOL)isManualPackage
{
    return self.package.kind == PackageInstallKindOTA
        || self.package.kind == PackageInstallKindNanoRegistry
        || self.package.kind == PackageInstallKindCallRecordingSound
        || self.package.kind == PackageInstallKindHideHomeBar;
}

- (BOOL)isDirectToolPackage
{
    return self.package.kind == PackageInstallKindDirectTool;
}

- (NSString *)manualActionTitleForIntent:(PackageQueueIntent)intent
{
    if (intent != PackageQueueIntentNone) {
        if (self.package.kind == PackageInstallKindNanoRegistry) {
            return (intent == PackageQueueIntentInstall) ? @"Cancel Apply" : @"Cancel Remove";
        }
        if (self.package.kind == PackageInstallKindCallRecordingSound) {
            return (intent == PackageQueueIntentInstall) ? @"Cancel Silence" : @"Cancel Restore";
        }
        if (self.package.kind == PackageInstallKindHideHomeBar) {
            return (intent == PackageQueueIntentInstall) ? @"Cancel Hide" : @"Cancel Restore";
        }
        return (intent == PackageQueueIntentInstall) ? @"Cancel Disable" : @"Cancel Enable";
    }
    if (self.package.kind == PackageInstallKindNanoRegistry) return @"Apply/Remove";
    if (self.package.kind == PackageInstallKindCallRecordingSound) return @"Silence/Restore";
    if (self.package.kind == PackageInstallKindHideHomeBar) return @"Hide/Restore";
    return @"Disable/Enable";
}

- (NSString *)manualStateText
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    if (self.package.kind == PackageInstallKindNanoRegistry) {
        if (intent == PackageQueueIntentInstall) return @"Apply Pending";
        if (intent == PackageQueueIntentUninstall) return @"Remove Pending";
        return @"Manual Control";
    }
    if (self.package.kind == PackageInstallKindCallRecordingSound) {
        if (intent == PackageQueueIntentInstall) return @"Silence Pending";
        if (intent == PackageQueueIntentUninstall) return @"Restore Pending";
        return @"Manual Control";
    }
    if (self.package.kind == PackageInstallKindHideHomeBar) {
        if (intent == PackageQueueIntentInstall) return @"Hide Pending";
        if (intent == PackageQueueIntentUninstall) return @"Restore Pending";
        return @"Manual Control";
    }
    if (intent == PackageQueueIntentInstall) return @"Disable Pending";
    if (intent == PackageQueueIntentUninstall) return @"Enable Pending";
    return @"Manual Control";
}

- (NSString *)toggleStateText
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    if (intent == PackageQueueIntentInstall) return @"Activation Pending";
    if (intent == PackageQueueIntentUninstall) return @"Deactivation Pending";
    if (self.package.isInstalled) return @"Installed";
    return @"Inactive";
}

- (UIColor *)toggleStateColor
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    if (intent == PackageQueueIntentInstall) return self.view.tintColor;
    if (intent == PackageQueueIntentUninstall) return UIColor.systemRedColor;
    if (self.package.isInstalled) return UIColor.systemGreenColor;
    return UIColor.secondaryLabelColor;
}

- (NSString *)packageStateText
{
    if ([self isDirectToolPackage]) return @"Manual Control";
    return [self isManualPackage] ? [self manualStateText] : [self toggleStateText];
}

- (UIColor *)packageStateColor
{
    if ([self isDirectToolPackage]) return UIColor.secondaryLabelColor;
    return [self isManualPackage] ? [self manualStateColor] : [self toggleStateColor];
}

- (UIColor *)manualStateColor
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    if (intent != PackageQueueIntentNone) return self.view.tintColor;
    return UIColor.secondaryLabelColor;
}

- (BOOL)presentQueueConflictIfNeededForIntent:(PackageQueueIntent)intent
{
    NSString *reason = nil;
    if ([[PackageQueue sharedQueue] canQueueIntent:intent
                                       forPackage:self.package
                                           reason:&reason]) {
        return NO;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Run Hide Home Bar Alone"
                                            message:reason ?: @"Hide Home Bar must be the only pending queue item."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    return YES;
}

- (NSArray<NSArray<NSString *> *> *)currentInfoRows
{
    NSMutableArray<NSArray<NSString *> *> *rows = [self.infoRows mutableCopy];
    [rows addObject:@[@"State", [self packageStateText]]];
    return rows;
}

- (void)queueManualIntent:(PackageQueueIntent)intent
{
    if ([self presentQueueConflictIfNeededForIntent:intent]) return;

    if (self.package.kind == PackageInstallKindNanoRegistry) {
        log_user("[INSTALLER] Pending watch-pairing %s\n",
                 intent == PackageQueueIntentInstall ? "apply" : "remove");
    } else if (self.package.kind == PackageInstallKindCallRecordingSound) {
        log_user("[INSTALLER] Pending call-recording sound %s\n",
                 intent == PackageQueueIntentInstall ? "silence" : "restore");
    } else if (self.package.kind == PackageInstallKindHideHomeBar) {
        log_user("[INSTALLER] Pending home bar %s\n",
                 intent == PackageQueueIntentInstall ? "hide" : "restore");
    } else {
        log_user("[INSTALLER] Pending OTA %s\n",
                 intent == PackageQueueIntentInstall ? "disable" : "enable");
    }
    [[PackageQueue sharedQueue] queueIntent:intent forPackage:self.package];
}

- (UIMenu *)manualActionMenu
{
    if (self.package.kind == PackageInstallKindNanoRegistry) {
        UIAction *apply = [UIAction actionWithTitle:@"Apply Pairing Override"
                                              image:[UIImage systemImageNamed:@"applewatch.radiowaves.left.and.right"]
                                         identifier:nil
                                            handler:^(__kindof UIAction *_) {
            [self queueManualIntent:PackageQueueIntentInstall];
        }];

        UIAction *remove = [UIAction actionWithTitle:@"Remove Pairing Override"
                                               image:[UIImage systemImageNamed:@"xmark.circle"]
                                          identifier:nil
                                             handler:^(__kindof UIAction *_) {
            [self queueManualIntent:PackageQueueIntentUninstall];
        }];
        remove.attributes = UIMenuElementAttributesDestructive;

        return [UIMenu menuWithTitle:@"Watch Pairing Override" children:@[apply, remove]];
    }

    if (self.package.kind == PackageInstallKindCallRecordingSound) {
        UIAction *silence = [UIAction actionWithTitle:@"Silence Disclosure Sounds"
                                                image:[UIImage systemImageNamed:@"speaker.slash.fill"]
                                           identifier:nil
                                              handler:^(__kindof UIAction *_) {
            [PackageDetailViewController
                presentCallRecordingDisclosureIfNeededFromViewController:self
                                                          confirmHandler:^{
                [self queueManualIntent:PackageQueueIntentInstall];
            }];
        }];
        silence.attributes = UIMenuElementAttributesDestructive;

        UIAction *restore = [UIAction actionWithTitle:@"Restore Original Sounds"
                                                image:[UIImage systemImageNamed:@"speaker.wave.2.fill"]
                                           identifier:nil
                                              handler:^(__kindof UIAction *_) {
            [self queueManualIntent:PackageQueueIntentUninstall];
        }];

        return [UIMenu menuWithTitle:@"Call Recording Sound" children:@[silence, restore]];
    }

    if (self.package.kind == PackageInstallKindHideHomeBar) {
        UIAction *hide = [UIAction actionWithTitle:@"Hide Home Bar"
                                             image:[UIImage systemImageNamed:@"line.3.horizontal"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *_) {
            [self queueManualIntent:PackageQueueIntentInstall];
        }];
        hide.attributes = UIMenuElementAttributesDestructive;

        UIAction *restore = [UIAction actionWithTitle:@"Restore Home Bar"
                                                image:[UIImage systemImageNamed:@"arrow.clockwise"]
                                           identifier:nil
                                              handler:^(__kindof UIAction *_) {
            [self queueManualIntent:PackageQueueIntentUninstall];
        }];

        return [UIMenu menuWithTitle:@"Home Bar" children:@[hide, restore]];
    }

    UIAction *disable = [UIAction actionWithTitle:@"Disable OTA Updates"
                                            image:[UIImage systemImageNamed:@"icloud.slash"]
                                       identifier:nil
                                          handler:^(__kindof UIAction *_) {
        [self queueManualIntent:PackageQueueIntentInstall];
    }];
    disable.attributes = UIMenuElementAttributesDestructive;

    UIAction *enable = [UIAction actionWithTitle:@"Enable OTA Updates"
                                           image:[UIImage systemImageNamed:@"icloud"]
                                      identifier:nil
                                         handler:^(__kindof UIAction *_) {
        [self queueManualIntent:PackageQueueIntentUninstall];
    }];

    return [UIMenu menuWithTitle:@"OTA Updates" children:@[disable, enable]];
}

- (instancetype)initWithPackage:(Package *)package
{
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _package = package;
        _infoRows = @[
            @[@"Author",   package.author],
            @[@"Version",  package.version],
        ];
        NSMutableArray<NSNumber *> *sections = [NSMutableArray array];
        if (package.unstableWarning.length > 0) {
            [sections addObject:@(PackageDetailSectionWarning)];
        }
        if (package.knownIssues.count > 0) {
            [sections addObject:@(PackageDetailSectionKnownIssues)];
        }
        if (package.settingsSection != NSIntegerMax && !package.isInstallDisabled) {
            [sections addObject:@(PackageDetailSectionAction)];
        }
        _settingsSummary = [SettingsViewController settingsSummaryForSection:package.settingsSection];
        if (_settingsSummary.count > 0) {
            [sections addObject:@(PackageDetailSectionSettings)];
        }
        [sections addObject:@(PackageDetailSectionInfo)];
        [sections addObject:@(PackageDetailSectionDescription)];
        _visibleSections = sections;
    }
    return self;
}

- (PackageDetailSection)sectionAtIndex:(NSInteger)index
{
    return (PackageDetailSection)[self.visibleSections[index] integerValue];
}

- (BOOL)hasSettingsBundle
{
    return self.package.settingsSection != NSIntegerMax;
}

- (BOOL)requiresThemeSelection
{
    return [self.package.identifier isEqualToString:@"com.darksword.themer"];
}

- (BOOL)isLiveWPPackage
{
    return [self.package.identifier isEqualToString:@"com.darksword.livewp"];
}

- (BOOL)needsThemeBeforeInstall
{
    return [self requiresThemeSelection] &&
           !self.package.isInstalled &&
           !settings_themer_has_selected_theme();
}

- (BOOL)needsLiveWPVideoBeforeInstall
{
    return [self isLiveWPPackage] &&
           !self.package.isInstalled &&
           ![SettingsViewController liveWPHasSelectedVideo];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.package.name;
    self.tableView.tableHeaderView = [self buildHeaderView];
    [self updateActionButton];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queueDidChange:)
                                                 name:PackageQueueDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queueDidChange:)
                                                 name:kSettingsActionsDidCompleteNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.settingsSummary = [SettingsViewController settingsSummaryForSection:self.package.settingsSection];
    self.tableView.tableHeaderView = [self buildHeaderView];
    [self.tableView reloadData];
    [self updateActionButton];
}

- (void)queueDidChange:(NSNotification *)note
{
    if (!self.isViewLoaded) return;
    self.tableView.tableHeaderView = [self buildHeaderView];
    [self.tableView reloadData];
    [self updateActionButton];
}

#pragma mark - Header

- (UIView *)buildHeaderView
{
    CGFloat width = self.view.bounds.size.width;
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = UIColor.clearColor;

    // Icon
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.image = [UIImage systemImageNamed:self.package.symbolName];
    iconView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:48.0 weight:UIImageSymbolWeightRegular];
    iconView.tintColor = self.view.tintColor;
    [header addSubview:iconView];

    // Name
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = self.package.name;
    nameLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    nameLabel.textColor = UIColor.labelColor;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview:nameLabel];

    // Subtitle: Category · Version
    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = [NSString stringWithFormat:@"%@  ·  Version %@", self.package.category, self.package.version];
    subLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    subLabel.textColor = UIColor.secondaryLabelColor;
    subLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview:subLabel];

    // Status badge (optional)
    UIView *badge = nil;
    if ([self isDirectToolPackage]) {
        badge = [self badgeWithText:@"MANUAL"
                         background:[UIColor.secondaryLabelColor colorWithAlphaComponent:0.16]
                          textColor:UIColor.secondaryLabelColor];
    } else if ([self isManualPackage]) {
        UIColor *color = [self manualStateColor];
        badge = [self badgeWithText:[self manualStateText].uppercaseString
                         background:[color colorWithAlphaComponent:0.16]
                          textColor:color];
    } else if (intent != PackageQueueIntentNone || self.package.isInstalled) {
        UIColor *color = [self packageStateColor];
        badge = [self badgeWithText:[self packageStateText].uppercaseString
                         background:[color colorWithAlphaComponent:0.16]
                          textColor:color];
    } else if (self.package.creatorOnly) {
        badge = [self badgeWithText:@"IN DEVELOPMENT"
                         background:[UIColor.systemPurpleColor colorWithAlphaComponent:0.16]
                          textColor:UIColor.systemPurpleColor];
    } else if (self.package.experimental) {
        badge = [self badgeWithText:@"EXPERIMENTAL"
                         background:[UIColor.systemRedColor colorWithAlphaComponent:0.16]
                          textColor:UIColor.systemRedColor];
    } else if (self.package.isInstallDisabled) {
        badge = [self badgeWithText:@"DISABLED"
                         background:[UIColor.systemRedColor colorWithAlphaComponent:0.16]
                          textColor:UIColor.systemRedColor];
    } else if (self.package.isNew) {
        badge = [self badgeWithText:@"NEW"
                         background:[UIColor colorWithRed:0.95 green:0.55 blue:0.05 alpha:0.18]
                          textColor:[UIColor systemOrangeColor]];
    }
    if (badge) {
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:badge];
    }

    NSMutableArray<NSLayoutConstraint *> *cs = [NSMutableArray array];
    [cs addObjectsFromArray:@[
        [iconView.topAnchor      constraintEqualToAnchor:header.topAnchor constant:16.0],
        [iconView.centerXAnchor  constraintEqualToAnchor:header.centerXAnchor],
        [iconView.widthAnchor    constraintEqualToConstant:60.0],
        [iconView.heightAnchor   constraintEqualToConstant:54.0],

        [nameLabel.topAnchor      constraintEqualToAnchor:iconView.bottomAnchor constant:12.0],
        [nameLabel.leadingAnchor  constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],

        [subLabel.topAnchor       constraintEqualToAnchor:nameLabel.bottomAnchor constant:3.0],
        [subLabel.leadingAnchor   constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [subLabel.trailingAnchor  constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
    ]];

    // Anchor the *last* element to the bottom so the header self-sizes. Bumped
    // the sub→badge gap from 6→12 and the badge→bottom gap to 14 so the pill
    // gets clear breathing room above and below (it was clipping the
    // description box below before).
    if (badge) {
        [cs addObjectsFromArray:@[
            [badge.topAnchor       constraintEqualToAnchor:subLabel.bottomAnchor constant:12.0],
            [badge.centerXAnchor   constraintEqualToAnchor:header.centerXAnchor],
            [badge.bottomAnchor    constraintEqualToAnchor:header.bottomAnchor constant:-14.0],
        ]];
    } else {
        [cs addObject:[subLabel.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12.0]];
    }
    [NSLayoutConstraint activateConstraints:cs];

    // tableHeaderView needs an explicit frame — auto layout inside it doesn't
    // size the slot. Ask the view for its natural height at the table's width.
    CGSize fit = [header systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                       withHorizontalFittingPriority:UILayoutPriorityRequired
                             verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    header.frame = CGRectMake(0, 0, width, fit.height);
    return header;
}

- (UIView *)badgeWithText:(NSString *)text background:(UIColor *)bg textColor:(UIColor *)fg
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = bg;
    container.layer.cornerRadius = 12.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.masksToBounds = YES;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightHeavy];
    label.textColor = fg;
    label.textAlignment = NSTextAlignmentCenter;
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor      constraintEqualToAnchor:container.topAnchor constant:4.0],
        [label.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor constant:-4.0],
        [label.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:10.0],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10.0],
    ]];
    return container;
}

#pragma mark - Action button

- (void)updateActionButton
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    BOOL installed = self.package.isInstalled;
    BOOL manual = [self isManualPackage];
    BOOL directTool = [self isDirectToolPackage];

    NSString *title;
    UIBarButtonItemStyle style = UIBarButtonItemStylePlain;
    UIColor *tint = nil;
    if (directTool) {
        title = @"Open Controls";
        tint = self.view.tintColor;
        style = UIBarButtonItemStyleDone;
    } else if (manual) {
        title = [self manualActionTitleForIntent:intent];
        tint = (intent != PackageQueueIntentNone)
            ? UIColor.secondaryLabelColor
            : self.view.tintColor;
        if (intent == PackageQueueIntentNone) style = UIBarButtonItemStyleDone;
    } else if (intent != PackageQueueIntentNone) {
        title = @"Cancel";
        tint = UIColor.secondaryLabelColor;
    } else if (installed && [self isLiveWPPackage] && [self hasSettingsBundle]) {
        title = @"Change Video";
        tint = self.view.tintColor;
        style = UIBarButtonItemStyleDone;
    } else if (installed) {
        title = @"Deactivate";
        tint = UIColor.systemRedColor;
    } else if (self.package.creatorOnly && !cyanide_is_creator()) {
        title = @"In Development";
        tint = UIColor.secondaryLabelColor;
    } else if (self.package.isInstallDisabled) {
        title = @"Disabled";
        tint = UIColor.secondaryLabelColor;
    } else if ([self needsThemeBeforeInstall]) {
        title = @"Select Theme";
        style = UIBarButtonItemStyleDone;
    } else if ([self needsLiveWPVideoBeforeInstall]) {
        title = @"Select Video";
        style = UIBarButtonItemStyleDone;
    } else {
        title = @"Activate";
        style = UIBarButtonItemStyleDone;
    }

    BOOL useMenu = manual && intent == PackageQueueIntentNone;
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:title
                                                             style:style
                                                            target:useMenu ? nil : self
                                                            action:useMenu ? nil : @selector(didTapAction)];
    if (useMenu) {
        item.menu = [self manualActionMenu];
    }
    if (tint) item.tintColor = tint;
    item.enabled = !self.package.isInstallDisabled || installed || intent != PackageQueueIntentNone;
    self.navigationItem.rightBarButtonItem = item;
}

- (void)didTapAction
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    if (intent != PackageQueueIntentNone) {
        log_user("[INSTALLER] Removed %s from queue\n", self.package.name.UTF8String);
        [[PackageQueue sharedQueue] removePackage:self.package];
        return;
    }
    if (self.package.creatorOnly && !cyanide_is_creator()) {
        return;
    }
    if (self.package.isInstallDisabled && !self.package.isInstalled) {
        log_user("[INSTALLER] %s is disabled for now: %s\n",
                 self.package.name.UTF8String,
                 self.package.installDisabledReason.UTF8String);
        return;
    }
    if ([self needsThemeBeforeInstall]) {
        [self promptSelectThemeBeforeInstall];
        return;
    }
    if ([self needsLiveWPVideoBeforeInstall]) {
        [self navigateToSettingsSection];
        return;
    }
    if ([self isDirectToolPackage]) {
        [self navigateToSettingsSection];
        return;
    }
    if (self.package.isInstalled && [self isLiveWPPackage] && [self hasSettingsBundle]) {
        [self navigateToSettingsSection];
        return;
    }
    if (NO && !self.package.isInstalled && [self hasSettingsBundle]) {
        [self promptConfigureBeforeInstall];
        return;
    }
    // Manual packages dispatch via menu — didTapAction should never run for
    // them when intent == None (the bar item carries a UIMenu instead of a
    // selector target).
    if ([self isManualPackage]) {
        return;
    } else if (self.package.isInstalled) {
        log_user("[INSTALLER] Pending deactivation: %s\n", self.package.name.UTF8String);
    } else {
        if ([self presentQueueConflictIfNeededForIntent:PackageQueueIntentInstall]) return;
        log_user("[INSTALLER] Pending activation: %s\n", self.package.name.UTF8String);
    }
    [[PackageQueue sharedQueue] toggleForPackage:self.package];
}

- (void)promptSelectThemeBeforeInstall
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select a Theme"
                                                                   message:@"Icon themes need a selected theme before they can be activated. Choose iOS 6 Theme or import a custom theme first."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Open Theme Settings"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *_) {
        [self navigateToSettingsSection];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptConfigureBeforeInstall
{
    NSString *msg = [NSString stringWithFormat:
        @"%@ has configurable options. Set them up first so the tweak applies with your preferences on the first activation.",
        self.package.name];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Customize Before Activating?"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Configure First"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *_) {
        [self navigateToSettingsSection];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate Anyway"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *_) {
        if ([self presentQueueConflictIfNeededForIntent:PackageQueueIntentInstall]) return;
        log_user("[INSTALLER] Pending activation: %s\n", self.package.name.UTF8String);
        [[PackageQueue sharedQueue] toggleForPackage:self.package];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.visibleSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ([self sectionAtIndex:section]) {
        case PackageDetailSectionWarning:      return 1;
        case PackageDetailSectionKnownIssues:  return 1;
        case PackageDetailSectionInfo:         return (NSInteger)[self currentInfoRows].count;
        case PackageDetailSectionAction:       return 1;
        case PackageDetailSectionSettings:     return (NSInteger)self.settingsSummary.count;
        case PackageDetailSectionDescription:  return 1;
        case PackageDetailSectionCount:        return 0;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch ([self sectionAtIndex:section]) {
        case PackageDetailSectionWarning:      return nil;
        case PackageDetailSectionKnownIssues:  return @"Known Issues";
        case PackageDetailSectionInfo:         return nil;
        case PackageDetailSectionAction:       return @"Configure";
        case PackageDetailSectionSettings:     return @"Current Settings";
        case PackageDetailSectionDescription:  return nil;
        case PackageDetailSectionCount:        return nil;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if ([self sectionAtIndex:section] == PackageDetailSectionAction) {
        return @"Settings can be changed before or after activation.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([self sectionAtIndex:indexPath.section]) {
        case PackageDetailSectionWarning: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WarningCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:@"WarningCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            // Wipe any previous subviews from cell reuse before rebuilding.
            for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];
            cell.textLabel.text   = nil;
            cell.imageView.image  = nil;
            cell.backgroundColor  = [UIColor.systemRedColor colorWithAlphaComponent:0.14];

            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
            icon.translatesAutoresizingMaskIntoConstraints = NO;
            icon.tintColor = UIColor.systemRedColor;
            icon.preferredSymbolConfiguration =
                [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightSemibold];
            [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [icon setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [cell.contentView addSubview:icon];

            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.text = self.package.unstableWarning;
            label.textColor = UIColor.systemRedColor;
            label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
            label.numberOfLines = 0;
            [cell.contentView addSubview:label];

            UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
            [NSLayoutConstraint activateConstraints:@[
                [icon.leadingAnchor    constraintEqualToAnchor:m.leadingAnchor],
                [icon.topAnchor        constraintEqualToAnchor:m.topAnchor constant:2.0],
                [icon.widthAnchor      constraintEqualToConstant:22.0],

                [label.leadingAnchor   constraintEqualToAnchor:icon.trailingAnchor constant:10.0],
                [label.trailingAnchor  constraintEqualToAnchor:m.trailingAnchor],
                [label.topAnchor       constraintEqualToAnchor:m.topAnchor],
                [label.bottomAnchor    constraintEqualToAnchor:m.bottomAnchor],
            ]];
            return cell;
        }
        case PackageDetailSectionKnownIssues: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KnownIssuesCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:@"KnownIssuesCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];
            cell.textLabel.text   = nil;
            cell.imageView.image  = nil;
            cell.backgroundColor  = UIColor.clearColor;

            NSArray<NSString *> *issues = self.package.knownIssues;
            UIColor *accent = UIColor.systemOrangeColor;

            UIView *card = [[UIView alloc] init];
            card.translatesAutoresizingMaskIntoConstraints = NO;
            card.backgroundColor = [accent colorWithAlphaComponent:0.06];
            card.layer.borderColor = [accent colorWithAlphaComponent:0.35].CGColor;
            card.layer.borderWidth = 1.0;
            card.layer.cornerRadius = 10.0;
            card.layer.cornerCurve = kCACornerCurveContinuous;
            card.layer.masksToBounds = YES;

            NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
            ps.headIndent = 12.0;
            ps.firstLineHeadIndent = 0.0;
            ps.paragraphSpacing = 6.0;
            ps.lineSpacing = 1.0;

            NSDictionary *bulletAttrs = @{
                NSFontAttributeName: [UIFont systemFontOfSize:13.0],
                NSForegroundColorAttributeName: accent,
                NSParagraphStyleAttributeName: ps,
            };
            NSDictionary *textAttrs = @{
                NSFontAttributeName: [UIFont systemFontOfSize:13.0],
                NSForegroundColorAttributeName: UIColor.labelColor,
                NSParagraphStyleAttributeName: ps,
            };

            NSMutableAttributedString *body = [[NSMutableAttributedString alloc] init];
            for (NSUInteger i = 0; i < issues.count; i++) {
                if (i > 0) [body appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                [body appendAttributedString:[[NSAttributedString alloc] initWithString:@"•  " attributes:bulletAttrs]];
                [body appendAttributedString:[[NSAttributedString alloc] initWithString:issues[i] attributes:textAttrs]];
            }

            UILabel *bodyLabel = [[UILabel alloc] init];
            bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
            bodyLabel.attributedText = body;
            bodyLabel.numberOfLines = 0;

            [card addSubview:bodyLabel];
            [cell.contentView addSubview:card];

            UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
            [NSLayoutConstraint activateConstraints:@[
                [card.leadingAnchor    constraintEqualToAnchor:m.leadingAnchor],
                [card.trailingAnchor   constraintEqualToAnchor:m.trailingAnchor],
                [card.topAnchor        constraintEqualToAnchor:m.topAnchor],
                [card.bottomAnchor     constraintEqualToAnchor:m.bottomAnchor],

                [bodyLabel.leadingAnchor   constraintEqualToAnchor:card.leadingAnchor constant:14],
                [bodyLabel.trailingAnchor  constraintEqualToAnchor:card.trailingAnchor constant:-14],
                [bodyLabel.topAnchor       constraintEqualToAnchor:card.topAnchor constant:12],
                [bodyLabel.bottomAnchor    constraintEqualToAnchor:card.bottomAnchor constant:-12],
            ]];
            return cell;
        }
        case PackageDetailSectionInfo: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                              reuseIdentifier:@"InfoCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            NSArray<NSArray<NSString *> *> *rows = [self currentInfoRows];
            NSArray<NSString *> *row = indexPath.row < (NSInteger)rows.count ? rows[indexPath.row] : @[];
            NSString *label = row.count > 0 ? row[0] : @"";
            NSString *value = row.count > 1 ? row[1] : @"";
            cell.textLabel.text = label;
            cell.detailTextLabel.text = value;
            cell.detailTextLabel.textColor = [label isEqualToString:@"State"]
                ? [self packageStateColor]
                : UIColor.secondaryLabelColor;
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
            return cell;
        }
        case PackageDetailSectionDescription: {
            static NSString *kDescID = @"DescCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kDescID];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:kDescID];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];
            cell.textLabel.text = nil;

            UILabel *descLabel = [[UILabel alloc] init];
            descLabel.translatesAutoresizingMaskIntoConstraints = NO;
            descLabel.numberOfLines = 0;
            descLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
            descLabel.textColor = UIColor.secondaryLabelColor;

            NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
            ps.lineSpacing = 3.0;
            ps.paragraphSpacing = 10.0;
            descLabel.attributedText = [[NSAttributedString alloc]
                initWithString:self.package.longDescription ?: @""
                    attributes:@{
                        NSFontAttributeName: descLabel.font,
                        NSForegroundColorAttributeName: descLabel.textColor,
                        NSParagraphStyleAttributeName: ps,
                    }];

            [cell.contentView addSubview:descLabel];
            UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
            [NSLayoutConstraint activateConstraints:@[
                [descLabel.topAnchor      constraintEqualToAnchor:m.topAnchor constant:2.0],
                [descLabel.bottomAnchor   constraintEqualToAnchor:m.bottomAnchor constant:-2.0],
                [descLabel.leadingAnchor  constraintEqualToAnchor:m.leadingAnchor],
                [descLabel.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
            ]];
            return cell;
        }
        case PackageDetailSectionSettings: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsSummaryCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                              reuseIdentifier:@"SettingsSummaryCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            }
            NSDictionary *row = self.settingsSummary[indexPath.row];
            cell.textLabel.text = row[@"title"];
            cell.detailTextLabel.text = row[@"value"];
            return cell;
        }
        case PackageDetailSectionAction: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                              reuseIdentifier:@"ActionCell"];
            }
            cell.textLabel.text = [self isDirectToolPackage]
                ? [NSString stringWithFormat:@"Open %@", self.package.name]
                : [NSString stringWithFormat:@"Customize %@", self.package.name];
            cell.textLabel.textColor = self.view.tintColor;
            cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
            cell.detailTextLabel.text = [self isDirectToolPackage]
                ? @"Choose a target and run actions directly"
                : @"Adjust options in the Settings tab";
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            cell.imageView.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
            cell.imageView.tintColor = self.view.tintColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        case PackageDetailSectionCount:
            break;
    }
    return [[UITableViewCell alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self sectionAtIndex:indexPath.section] != PackageDetailSectionAction) return;
    if (![self hasSettingsBundle]) return;
    [self navigateToSettingsSection];
}

- (void)navigateToSettingsSection
{
    UITabBarController *tab = self.tabBarController;
    NSUInteger settingsIndex = NSNotFound;
    UINavigationController *settingsNav = nil;
    for (NSUInteger i = 0; i < tab.viewControllers.count; i++) {
        UIViewController *vc = tab.viewControllers[i];
        if ([vc.tabBarItem.title isEqualToString:@"Settings"]) {
            settingsIndex = i;
            if ([vc isKindOfClass:UINavigationController.class]) {
                settingsNav = (UINavigationController *)vc;
            }
            break;
        }
    }
    if (settingsIndex == NSNotFound || !settingsNav) return;

    [settingsNav popToRootViewControllerAnimated:NO];
    SettingsViewController *bundle = [[SettingsViewController alloc] initWithUnderlyingSection:self.package.settingsSection
                                                                                   bundleTitle:self.package.name];
    bundle.installerReturnPackageName = self.package.name;
    [settingsNav pushViewController:bundle animated:NO];
    tab.selectedIndex = settingsIndex;
}

@end
