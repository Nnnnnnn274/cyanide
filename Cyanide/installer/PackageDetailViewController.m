//
//  PackageDetailViewController.m
//  Cyanide
//

#import "PackageDetailViewController.h"
#import "PackageQueue.h"
#import "../LogTextView.h"
#import "../SettingsViewController.h"


typedef NS_ENUM(NSInteger, PackageDetailSection) {
    PackageDetailSectionWarning = 0,
    PackageDetailSectionInfo,
    PackageDetailSectionAction,
    PackageDetailSectionDescription,
    PackageDetailSectionCount,
};

@interface PackageDetailViewController ()
@property (nonatomic, strong) Package *package;
@property (nonatomic, copy)   NSArray<NSArray<NSString *> *> *infoRows; // [[label, value], ...]
@property (nonatomic, copy)   NSArray<NSNumber *> *visibleSections;     // ordered PackageDetailSection values
@end

@implementation PackageDetailViewController

- (instancetype)initWithPackage:(Package *)package
{
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _package = package;
        _infoRows = @[
            @[@"Name",     package.name],
            @[@"Version",  package.version],
            @[@"Author",   package.author],
            @[@"Category", package.category],
        ];
        NSMutableArray<NSNumber *> *sections = [NSMutableArray array];
        if (package.unstableWarning.length > 0) {
            [sections addObject:@(PackageDetailSectionWarning)];
        }
        [sections addObject:@(PackageDetailSectionInfo)];
        if (package.settingsSection != NSIntegerMax && !package.isInstallDisabled) {
            [sections addObject:@(PackageDetailSectionAction)];
        }
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
    [self.tableView reloadData];
    [self updateActionButton];
}

- (void)queueDidChange:(NSNotification *)note
{
    if (!self.isViewLoaded) return;
    [self.tableView reloadData];
    [self updateActionButton];
}

#pragma mark - Header

- (UIView *)buildHeaderView
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 180.0)];
    header.backgroundColor = UIColor.clearColor;

    // Big icon
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.image = [UIImage systemImageNamed:self.package.symbolName];
    iconView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:64.0 weight:UIImageSymbolWeightRegular];
    iconView.tintColor = self.view.tintColor;
    [header addSubview:iconView];

    // Name
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = self.package.name;
    nameLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
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
    if (self.package.isInstallDisabled) {
        badge = [self badgeWithText:@"BUGGY"
                         background:[UIColor.systemRedColor colorWithAlphaComponent:0.16]
                          textColor:UIColor.systemRedColor];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:badge];
    } else if (self.package.isNew) {
        badge = [self badgeWithText:@"NEW"
                         background:[UIColor colorWithRed:0.95 green:0.55 blue:0.05 alpha:0.18]
                          textColor:[UIColor systemOrangeColor]];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:badge];
    }

    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor      constraintEqualToAnchor:header.topAnchor constant:16.0],
        [iconView.centerXAnchor  constraintEqualToAnchor:header.centerXAnchor],
        [iconView.widthAnchor    constraintEqualToConstant:80.0],
        [iconView.heightAnchor   constraintEqualToConstant:72.0],

        [nameLabel.topAnchor     constraintEqualToAnchor:iconView.bottomAnchor constant:10.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],

        [subLabel.topAnchor       constraintEqualToAnchor:nameLabel.bottomAnchor constant:4.0],
        [subLabel.leadingAnchor   constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [subLabel.trailingAnchor  constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
    ]];
    if (badge) {
        [NSLayoutConstraint activateConstraints:@[
            [badge.topAnchor      constraintEqualToAnchor:subLabel.bottomAnchor constant:8.0],
            [badge.centerXAnchor  constraintEqualToAnchor:header.centerXAnchor],
        ]];
    }

    return header;
}

- (UIView *)badgeWithText:(NSString *)text background:(UIColor *)bg textColor:(UIColor *)fg
{
    UILabel *pill = [[UILabel alloc] init];
    pill.text = [NSString stringWithFormat:@"  %@  ", text];
    pill.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightHeavy];
    pill.textColor = fg;
    pill.backgroundColor = bg;
    pill.textAlignment = NSTextAlignmentCenter;
    [pill sizeToFit];

    CGRect frame = pill.frame;
    frame.size.height = 22.0;
    pill.frame = frame;
    pill.layer.cornerRadius = frame.size.height / 2.0;
    pill.layer.masksToBounds = YES;
    return pill;
}

#pragma mark - Action button

- (void)updateActionButton
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:self.package];
    BOOL installed = self.package.isInstalled;

    NSString *title;
    UIBarButtonItemStyle style = UIBarButtonItemStylePlain;
    UIColor *tint = nil;
    if (intent != PackageQueueIntentNone) {
        title = @"Queued";
        tint = UIColor.secondaryLabelColor;
    } else if (installed) {
        title = @"Uninstall";
        tint = UIColor.systemRedColor;
    } else if (self.package.isInstallDisabled) {
        title = @"Disabled";
        tint = UIColor.secondaryLabelColor;
    } else {
        title = @"Install";
        style = UIBarButtonItemStyleDone;
    }

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:title
                                                             style:style
                                                            target:self
                                                            action:@selector(didTapAction)];
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
    if (self.package.isInstallDisabled && !self.package.isInstalled) {
        log_user("[INSTALLER] Signal Readouts is disabled for now: %s\n",
                 self.package.installDisabledReason.UTF8String);
        return;
    }
    if (self.package.isInstalled) {
        log_user("[INSTALLER] Queued uninstall: %s\n", self.package.name.UTF8String);
    } else {
        log_user("[INSTALLER] Queued install: %s\n", self.package.name.UTF8String);
    }
    [[PackageQueue sharedQueue] toggleForPackage:self.package];
}

#pragma mark - Data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.visibleSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ([self sectionAtIndex:section]) {
        case PackageDetailSectionWarning:     return 1;
        case PackageDetailSectionInfo:        return (NSInteger)self.infoRows.count;
        case PackageDetailSectionAction:      return 1;
        case PackageDetailSectionDescription: return 1;
        case PackageDetailSectionCount:       return 0;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch ([self sectionAtIndex:section]) {
        case PackageDetailSectionWarning:     return nil;
        case PackageDetailSectionInfo:        return @"Information";
        case PackageDetailSectionAction:      return @"Configure";
        case PackageDetailSectionDescription: return @"Description";
        case PackageDetailSectionCount:       return nil;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if ([self sectionAtIndex:section] == PackageDetailSectionAction) {
        return @"Settings can be changed any time — before or after install. Configuring before install is best so the tweak applies with your options on the very next run.";
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
        case PackageDetailSectionInfo: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                              reuseIdentifier:@"InfoCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            NSArray<NSString *> *row = self.infoRows[indexPath.row];
            cell.textLabel.text = row[0];
            cell.detailTextLabel.text = row[1];
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
            return cell;
        }
        case PackageDetailSectionDescription: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DescCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:@"DescCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.numberOfLines = 0;
                cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                cell.textLabel.textColor = UIColor.labelColor;
            }
            cell.textLabel.text = self.package.longDescription;
            return cell;
        }
        case PackageDetailSectionAction: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                              reuseIdentifier:@"ActionCell"];
            }
            cell.textLabel.text = [NSString stringWithFormat:@"Customize %@", self.package.name];
            cell.textLabel.textColor = self.view.tintColor;
            cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
            cell.detailTextLabel.text = @"Adjust options in the Settings tab";
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

    // Reset Settings nav to root, then push the bundle detail for this package.
    [settingsNav popToRootViewControllerAnimated:NO];
    SettingsViewController *bundle = [[SettingsViewController alloc] initWithUnderlyingSection:self.package.settingsSection
                                                                                   bundleTitle:self.package.name];
    bundle.installerReturnPackageName = self.package.name;
    [settingsNav pushViewController:bundle animated:NO];
    tab.selectedIndex = settingsIndex;
}

@end
