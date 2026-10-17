#import <AppKit/AppKit.h>

void activateMacApplication() {
    if (@available(macOS 14.0, *))
        [NSApp activate];
    else
        [[NSRunningApplication currentApplication] activateWithOptions:0];
}
