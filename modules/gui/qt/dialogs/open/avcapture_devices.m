/* AVFoundation capture device enumeration for the Open (advanced) dialog (macOS) */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#include "avcapture_devices.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void vlc_qt_avcapture_devices(int audio, vlc_qt_capture_device_cb cb, void *opaque)
{
    @autoreleasepool {
        NSArray *devices;
        if (audio)
            devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
        else
            devices = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]
                        arrayByAddingObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed]];

        for (AVCaptureDevice *device in devices)
            cb(opaque, [[device uniqueID] UTF8String], [[device localizedName] UTF8String]);
    }
}
