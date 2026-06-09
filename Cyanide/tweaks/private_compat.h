//
//  private_compat.h
//  Cyanide
//
//  Public builds do not have the private tweak submodule. Import the real APIs
//  when present; otherwise provide no-op shims so the shared app can still
//  compile and hide unavailable features at the catalog/UI layer.
//

#ifndef private_compat_h
#define private_compat_h

#include <stdbool.h>
#include <stdint.h>

#include "location_sim.h"
#include "call_recording_sound.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>
@class RemoteCallSession;
#endif

#ifndef __has_include
#define __has_include(x) 0
#endif

#if __has_include("private/rssidisplay.h") && \
    __has_include("private/typebanner.h") && \
    __has_include("private/notificationisland.h") && \
    __has_include("private/stagestrip.h") && \
    __has_include("private/ipadecryptor.h")

#define CYANIDE_PRIVATE_TWEAKS_AVAILABLE 1

#import "private/rssidisplay.h"
#import "private/typebanner.h"
#import "private/notificationisland.h"
#import "private/stagestrip.h"
#import "private/ipadecryptor.h"

#else

#define CYANIDE_PRIVATE_TWEAKS_AVAILABLE 0

#define TYPEBANNER_RC_FIRST_EXCEPTION_TIMEOUT_MS 8000
#define TYPEBANNER_RC_MOBILESMS_FIRST_EXCEPTION_TIMEOUT_MS 1000

static inline bool rssidisplay_apply_in_session(bool showWifi, bool showCell)
{
    (void)showWifi;
    (void)showCell;
    return false;
}

static inline bool rssidisplay_stop_in_session(void)
{
    return false;
}

static inline void rssidisplay_forget_remote_state(void)
{
}

static inline bool stagestrip_apply(int maxSlots)
{
    (void)maxSlots;
    return false;
}

static inline bool stagestrip_apply_in_session(int maxSlots)
{
    (void)maxSlots;
    return false;
}

static inline bool stagestrip_stop_in_session(void)
{
    return false;
}

static inline void stagestrip_start_control_loop(void)
{
}

static inline void stagestrip_stop_control_loop(void)
{
}

static inline void stagestrip_forget_remote_state(void)
{
}

#ifdef __OBJC__
static inline bool typebanner_prepare_in_springboard_session(void)
{
    return false;
}

static inline bool typebanner_prepare_in_springboard_remote_session(RemoteCallSession *session)
{
    (void)session;
    return false;
}

static inline bool typebanner_show_in_springboard_session(NSString *displayName)
{
    (void)displayName;
    return false;
}

static inline bool typebanner_show_in_springboard_remote_session(RemoteCallSession *session, NSString *displayName)
{
    (void)session;
    (void)displayName;
    return false;
}

static inline bool typebanner_hide_in_springboard_session(void)
{
    return false;
}

static inline bool typebanner_hide_in_springboard_remote_session(RemoteCallSession *session)
{
    (void)session;
    return false;
}

static inline bool typebanner_ensure_mobilesms_keepalive_in_springboard_session(uint32_t pid)
{
    (void)pid;
    return false;
}

static inline bool typebanner_ensure_mobilesms_keepalive_in_springboard_remote_session(RemoteCallSession *session, uint32_t pid)
{
    (void)session;
    (void)pid;
    return false;
}

static inline bool typebanner_release_mobilesms_keepalive_in_springboard_session(void)
{
    return true;
}

static inline bool typebanner_release_mobilesms_keepalive_in_springboard_remote_session(RemoteCallSession *session)
{
    (void)session;
    return true;
}

static inline NSString *typebanner_poll_in_mobilesms_session(void)
{
    return nil;
}

static inline NSString *typebanner_poll_in_mobilesms_remote_session(RemoteCallSession *session)
{
    (void)session;
    return nil;
}

static inline NSString *typebanner_poll_in_imagent_remote_session(RemoteCallSession *session)
{
    (void)session;
    return nil;
}

static inline void typebanner_diagnose_in_mobilesms_session(void)
{
}

static inline void typebanner_diagnose_in_mobilesms_remote_session(RemoteCallSession *session)
{
    (void)session;
}

static inline bool typebanner_run_once(void)
{
    return false;
}

static inline bool typebanner_run_once_with_mobile_session(RemoteCallSession **mobileSessionRef)
{
    (void)mobileSessionRef;
    return false;
}

static inline bool typebanner_run_once_with_mobile_session_and_current_springboard(RemoteCallSession **mobileSessionRef,
                                                                                  bool currentSpringBoardReady)
{
    (void)mobileSessionRef;
    (void)currentSpringBoardReady;
    return false;
}

static inline bool typebanner_run_once_with_cached_sessions(RemoteCallSession **mobileSessionRef,
                                                            RemoteCallSession **daemonSessionRef,
                                                            bool currentSpringBoardReady)
{
    (void)mobileSessionRef;
    (void)daemonSessionRef;
    (void)currentSpringBoardReady;
    return false;
}

static inline bool typebanner_has_remote_state(void)
{
    return false;
}

static inline void typebanner_forget_remote_state(void)
{
}

static inline bool typebanner_mobile_was_unreachable_last_tick(void)
{
    return false;
}

static inline bool notificationisland_apply_in_session(void)
{
    return false;
}

static inline bool notificationisland_tick_in_session(void)
{
    return false;
}

static inline bool notificationisland_show_sample_in_session(const char *title, const char *body)
{
    (void)title;
    (void)body;
    return false;
}

static inline bool notificationisland_stop_in_session(void)
{
    return false;
}

static inline void notificationisland_forget_remote_state(void)
{
}

static inline bool notificationisland_has_remote_state(void)
{
    return false;
}

static inline NSArray<NSDictionary<NSString *, NSString *> *> *ipadecryptor_installed_apps(void)
{
    return @[];
}

static inline NSString *ipadecryptor_display_name_for_bundle(NSString *bundleID)
{
    return bundleID.length > 0 ? bundleID : @"None selected";
}

static inline NSString *ipadecryptor_default_output_directory(void)
{
    return @"";
}

static inline NSString *ipadecryptor_app_store_account_summary(void)
{
    return @"IPA Decryptor is unavailable in this build.";
}

static inline bool ipadecryptor_has_app_store_account(void)
{
    return false;
}

static inline bool ipadecryptor_login_app_store(NSString *email,
                                                NSString *password,
                                                NSString *authCode,
                                                NSString **messageOut)
{
    (void)email;
    (void)password;
    (void)authCode;
    if (messageOut) *messageOut = @"IPA Decryptor is unavailable in this build.";
    return false;
}

static inline void ipadecryptor_clear_app_store_account(void)
{
}

static inline NSDictionary<NSString *, NSString *> *ipadecryptor_resolve_app_store_input(NSString *input,
                                                                                        NSString **messageOut)
{
    (void)input;
    if (messageOut) *messageOut = @"IPA Decryptor is unavailable in this build.";
    return nil;
}

static inline bool ipadecryptor_download_app_store_ipa(NSString *input,
                                                      NSString **downloadedPathOut,
                                                      NSString **messageOut)
{
    (void)input;
    if (downloadedPathOut) *downloadedPathOut = nil;
    if (messageOut) *messageOut = @"IPA Decryptor is unavailable in this build.";
    return false;
}

static inline bool ipadecryptor_probe_installed_app(NSString *bundleID, NSString **messageOut)
{
    (void)bundleID;
    if (messageOut) *messageOut = @"IPA Decryptor is unavailable in this build.";
    return false;
}

static inline bool ipadecryptor_start_decrypt_installed_app(NSString *bundleID, NSString **messageOut)
{
    (void)bundleID;
    if (messageOut) *messageOut = @"IPA Decryptor is unavailable in this build.";
    return false;
}
#endif

#endif

static inline bool cyanide_private_tweaks_available(void)
{
    return CYANIDE_PRIVATE_TWEAKS_AVAILABLE != 0;
}

#endif /* private_compat_h */
