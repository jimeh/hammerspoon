#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
@import Crashlytics;

// ----------------------- API Implementation ---------------------

/// hs.crash.crash()
/// Function
/// Causes Hammerspoon to immediately crash
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This is for testing purposes only, you are extremely unlikely to need this in normal Hammerspoon usage
static int burnTheWorld(lua_State *L __unused) {
    int *x = NULL;
    *x = 42;
    return 0;
}

/// hs.crash.throwObjCException(name, message)
/// Function
/// Causes Hammerspoon to generate an Objective C exception
///
/// Paramters:
///  * name - A string containing the name of the exception
///  * message - A human readabke string explaining the exception
///
/// Returns:
///  * None
///
/// Notes:
///  * Outside of a context of a Lua pcall() (or a C lua_pcall()), this will cause Hammerspoon to exit. We follow the safe behaviour of terminating the app on any unhandled Objective C exception.
static int throwTheWorld(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    [NSException raise:[skin toNSObjectAtIndex:1] format:@"%@", [skin toNSObjectAtIndex:2]];

    return 0;
}

// NOTE: Second parameter here is deliberately undocumented, it is covered in init.lua as a global variable
/// hs.crash.crashLog(logMessage)
/// Function
/// Leaves a breadcrumb log message in any Crashlytics crash dump generated by this Hammerspoon session
///
/// Parameters:
///  * logMessage - A string containing a message to log
///
/// Returns:
///  * None
///
/// Notes:
///  * This is probably only useful to extension developers. If you are trying to track down a confusing crash, and you have access to the Crashlytics project for Hammerspoon (or access to someone who has access!), this can be a useful way to leave breadcrumbs from Lua in the crash dump
static int crashLog(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    if (lua_toboolean(L, 2)) {
        [skin logBreadcrumb:[skin toNSObjectAtIndex:1]];
    } else {
        HSLOG(@"%s", lua_tostring(L, 1));
    }

    return 0;
}

/// hs.crash.crashKV(key, value)
/// Function
/// Sets a key/value pair in any Crashlytics crash dump generated by this Hamerspoon session
///
/// Parameters:
///  * key - A string containing the key name of the pair
///  * value - A string containing the value of the pair
///
/// Returns:
///  * None
static int crashKV(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    NSString *key = [skin toNSObjectAtIndex:1];
    NSString *value = [skin toNSObjectAtIndex:2];

    Crashlytics *crashlytics = [Crashlytics sharedInstance];
    [crashlytics setObjectValue:value forKey:key];

    return 0;
}

/// hs.crash.residentSize() -> integer or nil
/// Function
/// Gets the resident size of the Hammerspoon process
///
/// Parameters:
///  * None
///
/// Returns:
///  * An integer containing the amount of RAM in use by Hammerspoon (in bytes), or nil if an error occurred
static int residentSize(lua_State *L) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if (kerr == KERN_SUCCESS) {
        lua_pushinteger(L, info.resident_size);
    } else {
        lua_pushnil(L);
        NSLog(@"Error with task_info(): %s", mach_error_string(kerr));
    }

    return 1;
}

static const luaL_Reg crashlib[] = {
    {"crash", burnTheWorld},
    {"throwObjCException", throwTheWorld},
    {"_crashLog", crashLog},
    {"crashKV", crashKV},
    {"residentSize", residentSize},

    {NULL, NULL}
};

/* NOTE: The substring "hs_crash_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.crash.internal". */

int luaopen_hs_crash_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:crashlib metaFunctions:nil];

    return 1;
}
