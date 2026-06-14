//
//  appswitchergrid.m
//  Cyanide
//

#import "appswitchergrid.h"
#import "remote_objc.h"
#import "../TaskRop/RemoteCall.h"
#import "../LogTextView.h"
#import <stdio.h>

// Manually flip to true when collecting detailed App Switcher Grid logs.
static const bool kAppSwitcherGridDebugLogging = false;

#define ASG_DEBUG_LOG(fmt, ...) do { \
    if (kAppSwitcherGridDebugLogging) log_user(fmt, ##__VA_ARGS__); \
} while (0)

static uint64_t gASGSwitcherStyleMethod = 0;
static uint64_t gASGOriginalSwitcherStyleImp = 0;
static uint64_t gASGOriginalSwitcherStyle = 0;
static bool gASGHaveOriginalSwitcherStyle = false;
static bool gASGApplied = false;

static uint64_t asg_instance_method(uint64_t cls, uint64_t sel)
{
    if (!r_is_objc_ptr(cls) || sel == 0) return 0;
    return r_dlsym_call(R_TIMEOUT, "class_getInstanceMethod",
                        cls, sel, 0, 0, 0, 0, 0, 0);
}

static void asg_add_unique_object(uint64_t obj, uint64_t *objects, int *count, int capacity)
{
    if (!r_is_objc_ptr(obj) || !objects || !count || *count >= capacity) return;
    for (int i = 0; i < *count; i++) {
        if (objects[i] == obj) return;
    }
    objects[(*count)++] = obj;
}

static uint64_t asg_main_switcher(void)
{
    uint64_t cls = r_class("SBMainSwitcherViewController");
    if (!r_is_objc_ptr(cls) || !r_responds_main(cls, "sharedInstance")) return 0;
    return r_msg2_main(cls, "sharedInstance", 0, 0, 0, 0);
}

static int asg_collect_settings_objects(uint64_t settingsCls, uint64_t *objects, int capacity)
{
    int count = 0;
    if (!objects || capacity <= 0) return 0;

    if (r_is_objc_ptr(settingsCls)) {
        const char *classGetters[] = {
            "sharedInstance",
            "_sharedInstance",
            "settings",
            "sharedSettings",
        };
        for (int i = 0; i < (int)(sizeof(classGetters) / sizeof(classGetters[0])); i++) {
            if (r_responds_main(settingsCls, classGetters[i])) {
                asg_add_unique_object(r_msg2_main(settingsCls, classGetters[i], 0, 0, 0, 0),
                                      objects, &count, capacity);
            }
        }
    }

    uint64_t mainSwitcher = asg_main_switcher();
    asg_add_unique_object(mainSwitcher, objects, &count, capacity);
    if (r_is_objc_ptr(mainSwitcher)) {
        const char *ivars[] = {
            "_settings",
            "_appSwitcherSettings",
            "_switcherSettings",
        };
        for (int i = 0; i < (int)(sizeof(ivars) / sizeof(ivars[0])); i++) {
            asg_add_unique_object(r_ivar_value(mainSwitcher, ivars[i]), objects, &count, capacity);
        }

        const char *getters[] = {
            "settings",
            "appSwitcherSettings",
            "switcherSettings",
            "_appSwitcherSettings",
        };
        for (int i = 0; i < (int)(sizeof(getters) / sizeof(getters[0])); i++) {
            if (r_responds_main(mainSwitcher, getters[i])) {
                asg_add_unique_object(r_msg2_main(mainSwitcher, getters[i], 0, 0, 0, 0),
                                      objects, &count, capacity);
            }
        }
    }

    int settingsCount = 0;
    for (int i = 0; i < count; i++) {
        uint64_t obj = objects[i];
        if (r_is_objc_ptr(obj) && r_responds_main(obj, "setSwitcherStyle:")) {
            objects[settingsCount++] = obj;
        }
    }
    return settingsCount;
}

static void asg_capture_original_style(uint64_t settingsCls)
{
    if (gASGHaveOriginalSwitcherStyle) return;
    uint64_t settings[8] = {0};
    int count = asg_collect_settings_objects(settingsCls, settings, 8);
    for (int i = 0; i < count; i++) {
        if (r_responds_main(settings[i], "switcherStyle")) {
            gASGOriginalSwitcherStyle = r_msg2_main(settings[i], "switcherStyle", 0, 0, 0, 0);
            gASGHaveOriginalSwitcherStyle = true;
            ASG_DEBUG_LOG("[ASG][DEBUG] captured switcherStyle=%llu from 0x%llx\n",
                          gASGOriginalSwitcherStyle, settings[i]);
            return;
        }
    }
}

static int asg_apply_style_to_current_settings(uint64_t settingsCls, uint64_t style)
{
    uint64_t settings[8] = {0};
    int count = asg_collect_settings_objects(settingsCls, settings, 8);
    int touched = 0;
    for (int i = 0; i < count; i++) {
        r_msg2_main(settings[i], "setSwitcherStyle:", style, 0, 0, 0);
        touched++;
    }
    return touched;
}

static void asg_refresh_switcher_layout(void)
{
    uint64_t mainSwitcher = asg_main_switcher();
    if (!r_is_objc_ptr(mainSwitcher)) return;

    uint64_t transactionCls = r_class("CATransaction");
    if (r_is_objc_ptr(transactionCls)) {
        r_msg2_main(transactionCls, "begin", 0, 0, 0, 0);
        if (r_responds_main(transactionCls, "setDisableActions:")) {
            r_msg2_main(transactionCls, "setDisableActions:", 1, 0, 0, 0);
        }
    }

    uint64_t view = r_responds_main(mainSwitcher, "view")
        ? r_msg2_main(mainSwitcher, "view", 0, 0, 0, 0)
        : 0;
    if (r_is_objc_ptr(view)) {
        if (r_responds_main(view, "setNeedsLayout")) {
            r_msg2_main(view, "setNeedsLayout", 0, 0, 0, 0);
        }
        if (r_responds_main(view, "layoutIfNeeded")) {
            r_msg2_main(view, "layoutIfNeeded", 0, 0, 0, 0);
        }
    }

    if (r_is_objc_ptr(transactionCls)) {
        r_msg2_main(transactionCls, "commit", 0, 0, 0, 0);
    }
}

bool appswitchergrid_apply_in_session(void)
{
    uint64_t settingsCls = r_class("SBAppSwitcherSettings");
    uint64_t deckModifierCls = r_class("SBDeckSwitcherModifier");
    uint64_t switcherStyleSel = r_sel("switcherStyle");
    uint64_t dockUpdateModeSel = r_sel("dockUpdateMode");

    if (!r_is_objc_ptr(settingsCls) ||
        !r_is_objc_ptr(deckModifierCls) ||
        switcherStyleSel == 0 ||
        dockUpdateModeSel == 0) {
        printf("[ASG] missing classes/selectors settings=0x%llx deck=0x%llx switcherStyle=0x%llx dockUpdateMode=0x%llx\n",
               settingsCls, deckModifierCls, switcherStyleSel, dockUpdateModeSel);
        log_user("[ASG] Grid App Switcher is not available on this SpringBoard build.\n");
        return false;
    }

    uint64_t switcherStyleMethod = asg_instance_method(settingsCls, switcherStyleSel);
    uint64_t dockUpdateModeMethod = asg_instance_method(deckModifierCls, dockUpdateModeSel);
    if (!switcherStyleMethod || !dockUpdateModeMethod) {
        printf("[ASG] missing methods switcherStyle=0x%llx dockUpdateMode=0x%llx\n",
               switcherStyleMethod, dockUpdateModeMethod);
        log_user("[ASG] Grid App Switcher methods were not found.\n");
        return false;
    }

    uint64_t return2Imp = r_dlsym_call(R_TIMEOUT, "method_getImplementation",
                                       dockUpdateModeMethod, 0, 0, 0, 0, 0, 0, 0);
    if (!return2Imp) {
        printf("[ASG] dockUpdateMode IMP unavailable\n");
        log_user("[ASG] Could not resolve the grid switcher implementation.\n");
        return false;
    }

    if (!gASGOriginalSwitcherStyleImp || gASGSwitcherStyleMethod != switcherStyleMethod) {
        gASGOriginalSwitcherStyleImp = r_dlsym_call(R_TIMEOUT, "method_getImplementation",
                                                   switcherStyleMethod, 0, 0, 0, 0, 0, 0, 0);
        gASGSwitcherStyleMethod = switcherStyleMethod;
    }
    if (!gASGOriginalSwitcherStyleImp) {
        printf("[ASG] original switcherStyle IMP unavailable\n");
        log_user("[ASG] Could not save the original App Switcher style.\n");
        return false;
    }

    asg_capture_original_style(settingsCls);
    int preTouched = asg_apply_style_to_current_settings(settingsCls, 2);

    uint64_t oldImp = r_dlsym_call(R_TIMEOUT, "method_setImplementation",
                                   switcherStyleMethod, return2Imp, 0, 0, 0, 0, 0, 0);
    if (!oldImp) {
        if (gASGHaveOriginalSwitcherStyle) {
            asg_apply_style_to_current_settings(settingsCls, gASGOriginalSwitcherStyle);
        }
        printf("[ASG] method_setImplementation failed\n");
        log_user("[ASG] Failed to enable Grid App Switcher.\n");
        return false;
    }

    gASGApplied = true;
    int postTouched = asg_apply_style_to_current_settings(settingsCls, 2);
    asg_refresh_switcher_layout();
    printf("[ASG] switcherStyle method=0x%llx original=0x%llx grid=0x%llx old=0x%llx touched=%d/%d\n",
           switcherStyleMethod, gASGOriginalSwitcherStyleImp, return2Imp, oldImp, preTouched, postTouched);
    ASG_DEBUG_LOG("[ASG][DEBUG] switcherStyle method=0x%llx original=0x%llx grid=0x%llx old=0x%llx touched=%d/%d\n",
                  switcherStyleMethod, gASGOriginalSwitcherStyleImp, return2Imp, oldImp, preTouched, postTouched);
    log_user("[ASG] Grid App Switcher enabled. Respring restores stock.\n");
    return true;
}

bool appswitchergrid_stop_in_session(void)
{
    if (!gASGSwitcherStyleMethod || !gASGOriginalSwitcherStyleImp) {
        gASGApplied = false;
        return false;
    }

    uint64_t oldImp = r_dlsym_call(R_TIMEOUT, "method_setImplementation",
                                   gASGSwitcherStyleMethod,
                                   gASGOriginalSwitcherStyleImp,
                                   0, 0, 0, 0, 0, 0);
    bool ok = oldImp != 0;
    if (ok && gASGHaveOriginalSwitcherStyle) {
        uint64_t settingsCls = r_class("SBAppSwitcherSettings");
        asg_apply_style_to_current_settings(settingsCls, gASGOriginalSwitcherStyle);
        asg_refresh_switcher_layout();
    }
    printf("[ASG] restore switcherStyle method=0x%llx original=0x%llx old=0x%llx ok=%d\n",
           gASGSwitcherStyleMethod, gASGOriginalSwitcherStyleImp, oldImp, ok);
    gASGApplied = false;
    if (ok) {
        log_user("[ASG] Stock App Switcher style restored for this SpringBoard session.\n");
    } else {
        log_user("[ASG] Restore did not complete; respring will restore stock App Switcher.\n");
    }
    return ok;
}

void appswitchergrid_forget_remote_state(void)
{
    gASGSwitcherStyleMethod = 0;
    gASGOriginalSwitcherStyleImp = 0;
    gASGOriginalSwitcherStyle = 0;
    gASGHaveOriginalSwitcherStyle = false;
    gASGApplied = false;
}
