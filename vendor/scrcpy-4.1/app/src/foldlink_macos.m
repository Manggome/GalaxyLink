// FoldLink additions, 2026. App-local events only; no global keyboard monitor.
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include <SDL3/SDL.h>
#undef MIN
#undef MAX
#include "events.h"
#include "foldlink_macos.h"

static NSTimeInterval lastSwitch;
bool sc_foldlink_image_paste(void) {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    NSData *data = [pasteboard dataForType:NSPasteboardTypePNG];
    if (!data) {
        NSImage *image = [[NSImage alloc] initWithPasteboard:pasteboard];
        if (!image) {
            NSArray *urls = [pasteboard readObjectsForClasses:@[NSURL.class]
                options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}];
            if (urls.count == 1) image = [[NSImage alloc] initWithContentsOfURL:urls.firstObject];
        }
        if (!image) return false;
        if (image.size.width * image.size.height > 32000000) {
            fprintf(stdout, "FOLDLINK_IMAGE_ERROR:이미지가 너무 큽니다 (최대 3200만 화소).\n"); fflush(stdout); return true;
        }
        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
        data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    }
    if (!data) return false;
    if (data.length > 25 * 1024 * 1024) {
        fprintf(stdout, "FOLDLINK_IMAGE_ERROR:이미지가 너무 큽니다 (최대 25MB).\n"); fflush(stdout); return true;
    }
    NSString *directory = NSProcessInfo.processInfo.environment[@"FOLDLINK_CLIPBOARD_DIR"];
    if (!directory) return false;
    NSString *name = [NSUUID.UUID.UUIDString stringByAppendingString:@".png"];
    NSString *path = [directory stringByAppendingPathComponent:name];
    NSError *error;
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        fprintf(stdout, "FOLDLINK_IMAGE_ERROR:이미지를 준비하지 못했습니다.\n");
    } else {
        fprintf(stdout, "FOLDLINK_IMAGE:%s\n", name.UTF8String);
    }
    fflush(stdout);
    return true;
}
void sc_foldlink_language_request(void) {
    if (!NSApp.active || !SDL_GetKeyboardFocus()) return;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now - lastSwitch < 0.25) return;
    lastSwitch = now;
    sc_push_event(SC_EVENT_FOLDLINK_LANGUAGE);
}
bool sc_foldlink_reduce_motion(void) {
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
}
void sc_foldlink_macos_start(void) {
    static bool installed;
    if (installed) return;
    installed = true;
    // Let macOS own Caps Lock and input-source changes. Relaying both native
    // notifications and raw Caps Lock previously created a second language state.
}
