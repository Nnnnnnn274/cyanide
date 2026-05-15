//
//  PackageQueue.m
//  Cyanide
//

#import "PackageQueue.h"
#import "PackageCatalog.h"
#import "../SettingsViewController.h"

NSString * const PackageQueueDidChangeNotification = @"PackageQueueDidChangeNotification";

@interface PackageQueue ()
@property (nonatomic, strong) NSMutableArray<Package *> *installs;
@property (nonatomic, strong) NSMutableArray<Package *> *uninstalls;
@end

@implementation PackageQueue

+ (instancetype)sharedQueue
{
    static PackageQueue *q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = [[PackageQueue alloc] init]; });
    return q;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _installs   = [NSMutableArray array];
        _uninstalls = [NSMutableArray array];
    }
    return self;
}

- (NSArray<Package *> *)queuedInstalls
{
    NSMutableArray<Package *> *out = [self.installs mutableCopy];
    for (Package *p in [PackageCatalog allPackages]) {
        if (p.isInstallDisabled) continue;
        if (!p.isQueuedForApply) continue;
        if ([self packageInArray:out matching:p]) continue;
        if ([self packageInArray:self.uninstalls matching:p]) continue;
        [out addObject:p];
    }
    return out;
}

- (NSArray<Package *> *)queuedUninstalls { return [self.uninstalls copy]; }
- (NSInteger)pendingCount                { return (NSInteger)(self.queuedInstalls.count + self.queuedUninstalls.count); }

- (PackageQueueIntent)intentForPackage:(Package *)package
{
    if ([self packageInArray:self.installs matching:package])   return PackageQueueIntentInstall;
    if ([self packageInArray:self.uninstalls matching:package]) return PackageQueueIntentUninstall;
    if (package.isInstallDisabled) return PackageQueueIntentNone;
    if (package.isQueuedForApply) return PackageQueueIntentInstall;
    return PackageQueueIntentNone;
}

- (Package *)packageInArray:(NSArray<Package *> *)array matching:(Package *)package
{
    for (Package *p in array) {
        if ([p.identifier isEqualToString:package.identifier]) return p;
    }
    return nil;
}

- (void)toggleForPackage:(Package *)package
{
    PackageQueueIntent current = [self intentForPackage:package];
    if (current != PackageQueueIntentNone) {
        [self removePackage:package];
        return;
    }
    if (package.isInstallDisabled && !package.isInstalled) return;
    if (package.isInstalled) {
        [self.uninstalls addObject:package];
    } else {
        [self.installs addObject:package];
    }
    [self notifyChange];
}

- (void)removePackage:(Package *)package
{
    Package *match = [self packageInArray:self.installs matching:package];
    if (match) [self.installs removeObject:match];
    match = [self packageInArray:self.uninstalls matching:package];
    if (match) [self.uninstalls removeObject:match];
    if (package.isQueuedForApply) {
        [package applyCommittedState:NO];
    }
    [self notifyChange];
}

- (void)clear
{
    NSArray<Package *> *queuedForApply = self.queuedInstalls;
    if (queuedForApply.count == 0 && self.uninstalls.count == 0) return;
    for (Package *pkg in queuedForApply) {
        if (![self packageInArray:self.installs matching:pkg] && pkg.isQueuedForApply) {
            [pkg applyCommittedState:NO];
        }
    }
    [self.installs removeAllObjects];
    [self.uninstalls removeAllObjects];
    [self notifyChange];
}

- (void)commit
{
    NSArray<Package *> *toInstall   = self.queuedInstalls;
    NSArray<Package *> *toUninstall = self.queuedUninstalls;

    for (Package *pkg in toInstall)   [pkg applyCommittedState:YES];
    for (Package *pkg in toUninstall) [pkg applyCommittedState:NO];

    [self.installs removeAllObjects];
    [self.uninstalls removeAllObjects];
    [self notifyChange];

    settings_run_actions();
}

- (void)notifyChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                        object:self];
}

@end
