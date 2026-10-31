/*
 * Adapted from flutter_webrtc 1.6.3, Copyright (c) 2018 湖北捷智云技术有限公司.
 * MIT license: see LICENSE in this directory.
 */
package com.cloudwebrtc.webrtc;

import android.util.Log;
import org.webrtc.CameraVideoCapturer;

class CameraEventsHandler implements CameraVideoCapturer.CameraEventsHandler {
    public enum CameraState { NEW, OPENING, OPENED, CLOSED, DISCONNECTED, ERROR, FREEZED }
    private static final String TAG = FlutterWebRTCPlugin.TAG;
    private volatile CameraState state = CameraState.NEW;

    public void waitForCameraOpen() {
        // startCapture is asynchronous. Waiting here blocks Flutter's platform
        // thread, preventing texture consumption and the first camera frame.
    }

    public void waitForCameraClosed() {
        while (state != CameraState.CLOSED && state != CameraState.ERROR
                && state != CameraState.DISCONNECTED) {
            try {
                Thread.sleep(1);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    @Override
    public void onCameraError(String description) {
        Log.e(TAG, "CameraEventsHandler.onCameraError: " + description);
        state = CameraState.ERROR;
    }

    @Override
    public void onCameraDisconnected() { state = CameraState.DISCONNECTED; }

    @Override
    public void onCameraFreezed(String description) {
        Log.w(TAG, "CameraEventsHandler.onCameraFreezed: " + description);
        state = CameraState.FREEZED;
    }

    @Override
    public void onCameraOpening(String cameraName) { state = CameraState.OPENING; }

    @Override
    public void onFirstFrameAvailable() { state = CameraState.OPENED; }

    @Override
    public void onCameraClosed() { state = CameraState.CLOSED; }
}
