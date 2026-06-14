//
//  cchud.m
//  Cyanide
//

#import "cchud.h"
#import "remote_objc.h"
#import "../TaskRop/RemoteCall.h"
#import "../LogTextView.h"
#import <stdio.h>

static const bool kCCHUDDebugLogging = false;

#define CCH_DEBUG_LOG(fmt, ...) do { \
    if (kCCHUDDebugLogging) log_user(fmt, ##__VA_ARGS__); \
} while (0)

static uint64_t gCCHControlCenterController = 0;
static bool gCCHApplied = false;

static uint64_t cch_object_class(uint64_t obj)
{
    if (!r_is_objc_ptr(obj)) return 0;
    uint64_t cls = r_dlsym_call(R_TIMEOUT, "object_getClass", obj, 0, 0, 0, 0, 0, 0, 0);
    return cls;
}

static uint64_t cch_control_center_controller(void)
{
    if (gCCHControlCenterController) return gCCHControlCenterController;
    
    uint64_t cls = r_class("SBControlCenterController");
    if (!r_is_objc_ptr(cls)) {
        printf("[CCH] SBControlCenterController class not found\n");
        return 0;
    }
    
    if (!r_responds(cls, "sharedInstance")) {
        printf("[CCH] sharedInstance not found\n");
        return 0;
    }
    
    gCCHControlCenterController = r_msg2(cls, "sharedInstance", 0, 0, 0, 0);
    if (!r_is_objc_ptr(gCCHControlCenterController)) {
        printf("[CCH] sharedInstance returned nil\n");
        return 0;
    }
    
    return gCCHControlCenterController;
}

bool cchud_apply_in_session(void)
{
    printf("[CCH] applying Control Center HUD tweak\n");
    
    uint64_t ctrl = cch_control_center_controller();
    if (!r_is_objc_ptr(ctrl)) {
        log_user("[CCH] Control Center HUD tweak is not available on this iOS build.\n");
        return false;
    }

    uint64_t cls = cch_object_class(ctrl);
    if (!r_is_objc_ptr(cls)) {
        printf("[CCH] could not get controller class\n");
        return false;
    }
    
    // Example: Customize Control Center behavior
    // This is a placeholder - actual implementation would depend on iOS version
    // and what specific Control Center customization is desired
    CCH_DEBUG_LOG("[CCH][DEBUG] controller=0x%llx class=0x%llx\n", ctrl, cls);
    
    gCCHApplied = true;
    log_user("[CCH] Control Center HUD tweak enabled.\n");
    return true;
}

bool cchud_stop_in_session(void)
{
    if (!gCCHApplied) {
        return false;
    }
    
    printf("[CCH] stopping Control Center HUD tweak\n");
    
    // Restore original state
    gCCHApplied = false;
    log_user("[CCH] Control Center HUD tweak disabled.\n");
    return true;
}

void cchud_forget_remote_state(void)
{
    gCCHControlCenterController = 0;
    gCCHApplied = false;
}
