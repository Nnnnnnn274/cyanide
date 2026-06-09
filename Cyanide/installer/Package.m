//
//  Package.m
//  Cyanide
//

#import "Package.h"
#import "PackageQueue.h"
#import "../SettingsViewController.h"
#import "../PatreonAuth.h"
#import "../LogTextView.h"

@implementation Package

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                  shortDescription:(NSString *)shortDescription
                   longDescription:(NSString *)longDescription
                           version:(NSString *)version
                            author:(NSString *)author
                          category:(NSString *)category
                        symbolName:(NSString *)symbolName
                              kind:(PackageInstallKind)kind
                        enabledKey:(NSString *)enabledKey
                             isNew:(BOOL)isNew
{
    if ((self = [super init])) {
        _identifier       = [identifier copy];
        _name             = [name copy];
        _shortDescription = [shortDescription copy];
        _longDescription  = [longDescription copy];
        _version          = [version copy];
        _author           = [author copy];
        _category         = [category copy];
        _symbolName       = [symbolName copy];
        _kind             = kind;
        _enabledKey       = [enabledKey copy];
        _isNew            = isNew;
        _settingsSection  = NSIntegerMax;
    }
    return self;
}

- (BOOL)isInstalled
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    switch (self.kind) {
        case PackageInstallKindToggle:
            if (!self.enabledKey) return NO;
            return [d boolForKey:self.enabledKey];
        case PackageInstallKindOTA:
        case PackageInstallKindNanoRegistry:
        case PackageInstallKindCallRecordingSound:
        case PackageInstallKindHideHomeBar:
            // Manual-control packages: no persistent "installed" state from
            // the app's POV. The detail view shows an Apply/Remove menu and
            // each commit is a fresh one-shot run.
            return NO;
        case PackageInstallKindDirectTool:
            return NO;
    }
}

- (BOOL)isQueuedForApply
{
    if (self.kind != PackageInstallKindToggle || !self.enabledKey) return NO;
    if (self.isInstallDisabled) return NO;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return [d boolForKey:self.enabledKey] && !settings_tweak_is_applied(self.enabledKey);
}

- (BOOL)isInstallDisabled
{
    if (self.installDisabledReason.length > 0) return YES;
    if (self.experimental) {
        BOOL experimentalOn = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsExperimentalTweaksEnabled];
        if (!experimentalOn || !(cyanide_is_patron() || cyanide_is_creator())) return YES;
    }
    if (self.creatorOnly && !cyanide_is_creator()) return YES;
    return NO;
}

- (void)install   { [[PackageQueue sharedQueue] toggleForPackage:self]; }
- (void)uninstall { [[PackageQueue sharedQueue] toggleForPackage:self]; }

// Called by PackageQueue.commit — writes the persisted state without
// triggering settings_run_actions itself (the queue does that once).
- (void)applyCommittedState:(BOOL)installed
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    switch (self.kind) {
        case PackageInstallKindToggle:
            if (self.enabledKey) {
                [d setBool:installed forKey:self.enabledKey];
                [d synchronize];
            }
            return;
        case PackageInstallKindOTA:
            if (settings_apply_ota_disabled(installed)) {
                log_user("[INSTALLER] OTA updates %s.\n", installed ? "disabled" : "enabled");
            } else {
                log_user("[INSTALLER] OTA %s failed; install state was not changed.\n",
                         installed ? "disable" : "enable");
            }
            return;
        case PackageInstallKindNanoRegistry:
            if (settings_apply_nano_registry_now(installed)) {
                log_user("[INSTALLER] Watch pairing override %s.\n",
                         installed ? "applied" : "removed");
            } else {
                log_user("[INSTALLER] Watch pairing override %s failed; state was not changed.\n",
                         installed ? "apply" : "remove");
            }
            return;
        case PackageInstallKindCallRecordingSound:
            if (settings_apply_call_recording_sound_disabled(installed)) {
                log_user("[INSTALLER] Call recording disclosure sound %s.\n",
                         installed ? "silenced" : "restored");
            } else {
                log_user("[INSTALLER] Call recording disclosure sound %s failed.\n",
                         installed ? "silence" : "restore");
            }
            return;
        case PackageInstallKindHideHomeBar:
            if (settings_apply_hide_home_bar_hidden(installed)) {
                log_user("[INSTALLER] Home bar %s.\n",
                         installed ? "hidden; respring to apply" : "restore queued; respring to apply");
            } else {
                log_user("[INSTALLER] Home bar %s failed.\n",
                         installed ? "hide" : "restore");
            }
            return;
        case PackageInstallKindDirectTool:
            return;
    }
}

@end
