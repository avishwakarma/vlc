/* AVFoundation capture device enumeration for the Open (advanced) dialog (macOS) */
#ifndef VLC_QT_AVCAPTURE_DEVICES_H
#define VLC_QT_AVCAPTURE_DEVICES_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*vlc_qt_capture_device_cb)(void *opaque, const char *unique_id, const char *name);

/* Calls `cb` for every video (audio = 0, same list as the avcapture access) or
 * audio (audio != 0, same list as the qtsound access) capture device. */
void vlc_qt_avcapture_devices(int audio, vlc_qt_capture_device_cb cb, void *opaque);

#ifdef __cplusplus
}
#endif

#endif
