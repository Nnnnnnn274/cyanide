//
//  PackagesViewController.m
//  Cyanide
//

#import "PackagesViewController.h"
#import "PackageCatalog.h"
#import "PackageDetailViewController.h"
#import "PackageQueue.h"
#import "../SettingsViewController.h"

static NSString * const kPackageCellID         = @"PackageCell";
static NSString * const kGroupByCategoryDefault = @"installer.groupByCategory";

@interface PackagesViewController () <UISearchResultsUpdating>
@property (nonatomic, copy)   NSArray<Package *> *allPackagesSorted;
@property (nonatomic, copy)   NSArray<Package *> *flatPackages;        // shown when !groupByCategory
@property (nonatomic, copy)   NSArray<NSString *> *visibleCategories;  // shown when groupByCategory
@property (nonatomic, copy)   NSDictionary<NSString *, NSArray<Package *> *> *packagesByCategory;
@property (nonatomic, copy)   NSString *searchText;
@property (nonatomic, assign) BOOL groupByCategory;
@property (nonatomic, strong) UISearchController *searchCtl;
@end

@implementation PackagesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Installer";
    self.navigationItem.title = @"Installer";

    self.groupByCategory = [[NSUserDefaults standardUserDefaults] boolForKey:kGroupByCategoryDefault];
    self.searchText = @"";

    self.allPackagesSorted = [[PackageCatalog allPackages]
        sortedArrayUsingComparator:^NSComparisonResult(Package *a, Package *b) {
            return [a.name caseInsensitiveCompare:b.name];
        }];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76.0;
    // Tighten the gap between the search bar / nav bar and the first row.
    // iOS 15+ inset-grouped tables add ~22pt of "section header top padding"
    // above section 0 by default; collapse it so the package block sits
    // right under the search field.
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    // Search controller pinned in the nav bar so it shows above the table.
    self.searchCtl = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchCtl.searchResultsUpdater = self;
    self.searchCtl.obscuresBackgroundDuringPresentation = NO;
    self.searchCtl.searchBar.placeholder = @"Search tweaks";
    self.navigationItem.searchController = self.searchCtl;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    [self installSortBarButton];
    [self rebuildFilteredData];

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
    [self rebuildFilteredData];
    [self.tableView reloadData];
}

- (void)queueDidChange:(NSNotification *)note
{
    if (!self.isViewLoaded) return;
    [self.tableView reloadData];
}

#pragma mark - Sort menu

- (void)installSortBarButton
{
    UIAction *flat = [UIAction actionWithTitle:@"Alphabetical"
                                         image:[UIImage systemImageNamed:@"list.bullet"]
                                    identifier:nil
                                       handler:^(UIAction *_) {
        [self applyGroupByCategory:NO];
    }];
    flat.state = self.groupByCategory ? UIMenuElementStateOff : UIMenuElementStateOn;

    UIAction *byCat = [UIAction actionWithTitle:@"By Category"
                                          image:[UIImage systemImageNamed:@"folder"]
                                     identifier:nil
                                        handler:^(UIAction *_) {
        [self applyGroupByCategory:YES];
    }];
    byCat.state = self.groupByCategory ? UIMenuElementStateOn : UIMenuElementStateOff;

    UIMenu *menu = [UIMenu menuWithTitle:@"Sort" children:@[flat, byCat]];
    UIBarButtonItem *btn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"]
                 menu:menu];
    self.navigationItem.rightBarButtonItem = btn;
}

- (void)applyGroupByCategory:(BOOL)group
{
    if (_groupByCategory == group) return;
    _groupByCategory = group;
    [[NSUserDefaults standardUserDefaults] setBool:group forKey:kGroupByCategoryDefault];
    [self installSortBarButton];
    [self rebuildFilteredData];
    [self.tableView reloadData];
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *q = searchController.searchBar.text ?: @"";
    if ([q isEqualToString:self.searchText]) return;
    self.searchText = q;
    [self rebuildFilteredData];
    [self.tableView reloadData];
}

#pragma mark - Filtering / bucketing

- (BOOL)package:(Package *)pkg matchesQuery:(NSString *)q
{
    if (q.length == 0) return YES;
    NSStringCompareOptions opt = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    if ([pkg.name             rangeOfString:q options:opt].location != NSNotFound) return YES;
    if ([pkg.shortDescription rangeOfString:q options:opt].location != NSNotFound) return YES;
    if ([pkg.category         rangeOfString:q options:opt].location != NSNotFound) return YES;
    return NO;
}

- (void)rebuildFilteredData
{
    NSMutableArray<Package *> *filtered = [NSMutableArray array];
    for (Package *p in self.allPackagesSorted) {
        if ([self package:p matchesQuery:self.searchText]) [filtered addObject:p];
    }
    self.flatPackages = filtered;

    if (!self.groupByCategory) {
        self.visibleCategories = nil;
        self.packagesByCategory = nil;
        return;
    }

    NSMutableArray<NSString *> *cats = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSArray<Package *> *> *bucket = [NSMutableDictionary dictionary];
    for (NSString *cat in [PackageCatalog categoriesInOrder]) {
        NSMutableArray<Package *> *inCat = [NSMutableArray array];
        for (Package *p in filtered) {
            if ([p.category isEqualToString:cat]) [inCat addObject:p];
        }
        if (inCat.count > 0) {
            [cats addObject:cat];
            bucket[cat] = inCat;
        }
    }
    self.visibleCategories = cats;
    self.packagesByCategory = bucket;
}

#pragma mark - Data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.groupByCategory) return (NSInteger)self.visibleCategories.count;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.groupByCategory) {
        NSString *cat = self.visibleCategories[section];
        return (NSInteger)self.packagesByCategory[cat].count;
    }
    return (NSInteger)self.flatPackages.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.groupByCategory) return self.visibleCategories[section];
    return nil;
}

- (Package *)packageAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.groupByCategory) {
        NSString *cat = self.visibleCategories[indexPath.section];
        return self.packagesByCategory[cat][indexPath.row];
    }
    return self.flatPackages[indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kPackageCellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:kPackageCellID];
    }

    Package *pkg = [self packageAtIndexPath:indexPath];

    // UIListContentConfiguration with a fixed reservedLayoutSize so every
    // SF Symbol occupies the same horizontal slot regardless of its intrinsic
    // aspect ratio. Without this, wider glyphs (apps.iphone, antenna.*) push
    // their text further right than narrower ones (thermometer, sun.max).
    UIListContentConfiguration *config = [UIListContentConfiguration subtitleCellConfiguration];
    config.image = [UIImage systemImageNamed:pkg.symbolName];
    config.imageProperties.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightRegular];
    UIColor *mainColor = pkg.isInstallDisabled ? UIColor.secondaryLabelColor : self.view.tintColor;
    config.imageProperties.tintColor       = mainColor;
    config.imageProperties.reservedLayoutSize = CGSizeMake(34.0, 28.0);
    config.imageProperties.maximumSize     = CGSizeMake(28.0, 28.0);
    config.imageToTextPadding              = 14.0;
    config.text = pkg.name;
    config.textProperties.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    if (pkg.isInstallDisabled) config.textProperties.color = UIColor.secondaryLabelColor;
    config.secondaryText = pkg.shortDescription;
    config.secondaryTextProperties.color = pkg.isInstallDisabled ? UIColor.tertiaryLabelColor : UIColor.secondaryLabelColor;
    config.secondaryTextProperties.numberOfLines = 2;
    config.textToSecondaryTextVerticalPadding = 3.0;
    NSDirectionalEdgeInsets m = config.directionalLayoutMargins;
    m.top    = 14.0;
    m.bottom = 14.0;
    config.directionalLayoutMargins = m;
    cell.contentConfiguration = config;

    cell.accessoryView = [self accessoryViewForPackage:pkg];
    if (!cell.accessoryView) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (UIView *)accessoryViewForPackage:(Package *)pkg
{
    PackageQueueIntent intent = [[PackageQueue sharedQueue] intentForPackage:pkg];
    if (intent != PackageQueueIntentNone) {
        NSString *text = (intent == PackageQueueIntentInstall) ? @"Queued" : @"Removing";
        UIColor *color = self.view.tintColor;
        return [self pillWithText:text
                       background:[color colorWithAlphaComponent:0.18]
                        textColor:color];
    }
    if (pkg.isInstalled) {
        return [self pillWithText:@"Installed"
                       background:[UIColor colorWithRed:0.16 green:0.55 blue:0.32 alpha:0.18]
                        textColor:[UIColor systemGreenColor]];
    }
    if (pkg.isInstallDisabled) {
        return [self pillWithText:@"BUGGY"
                       background:[[UIColor systemRedColor] colorWithAlphaComponent:0.16]
                        textColor:[UIColor systemRedColor]];
    }
    if ([pkg.category caseInsensitiveCompare:@"Beta"] == NSOrderedSame) {
        return [self pillWithText:@"BETA"
                       background:[[UIColor systemPurpleColor] colorWithAlphaComponent:0.18]
                        textColor:[UIColor systemPurpleColor]];
    }
    if (pkg.isNew) {
        return [self pillWithText:@"NEW"
                       background:[UIColor colorWithRed:0.95 green:0.55 blue:0.05 alpha:0.18]
                        textColor:[UIColor systemOrangeColor]];
    }
    return nil;
}

- (UIView *)pillWithText:(NSString *)text background:(UIColor *)bg textColor:(UIColor *)fg
{
    UILabel *pill = [[UILabel alloc] init];
    pill.text = text;
    pill.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightHeavy];
    pill.textColor = fg;
    pill.backgroundColor = bg;
    pill.textAlignment = NSTextAlignmentCenter;
    [pill sizeToFit];

    CGRect frame = pill.frame;
    frame.size.width  += 14.0;
    frame.size.height = 22.0;
    pill.frame = frame;

    pill.layer.cornerRadius = frame.size.height / 2.0;
    pill.layer.masksToBounds = YES;
    return pill;
}

#pragma mark - Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Package *pkg = [self packageAtIndexPath:indexPath];
    PackageDetailViewController *detail = [[PackageDetailViewController alloc] initWithPackage:pkg];
    [self.navigationController pushViewController:detail animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Package *pkg = [self packageAtIndexPath:indexPath];
    PackageQueue *q = [PackageQueue sharedQueue];
    PackageQueueIntent intent = [q intentForPackage:pkg];
    if (pkg.isInstallDisabled && !pkg.isInstalled && intent == PackageQueueIntentNone) return nil;

    NSString *title;
    UIColor *color;
    NSString *symbol;
    if (intent != PackageQueueIntentNone) {
        title  = @"Remove";
        color  = [UIColor systemGrayColor];
        symbol = @"xmark.circle";
    } else if (pkg.isInstalled) {
        title  = @"Uninstall";
        color  = [UIColor systemRedColor];
        symbol = @"trash";
    } else {
        title  = @"Queue";
        color  = self.view.tintColor;
        symbol = @"tray.and.arrow.down";
    }

    UIContextualAction *action = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:title
                          handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [q toggleForPackage:pkg];
        done(YES);
    }];
    action.backgroundColor = color;
    action.image = [UIImage systemImageNamed:symbol];

    UISwipeActionsConfiguration *cfg = [UISwipeActionsConfiguration configurationWithActions:@[action]];
    cfg.performsFirstActionWithFullSwipe = YES;
    return cfg;
}

@end
