// IRemoteInterface.aidl
package com.clashmo.android.service;

import com.clashmo.android.service.ICallbackInterface;
import com.clashmo.android.service.IEventInterface;
import com.clashmo.android.service.IResultInterface;
import com.clashmo.android.service.IVoidInterface;
import com.clashmo.android.service.models.VpnOptions;
import com.clashmo.android.service.models.NotificationParams;

interface IRemoteInterface {
    void invokeAction(in String data, in ICallbackInterface callback);
    void quickSetup(in String initParamsString, in String setupParamsString, in ICallbackInterface callback, in IVoidInterface onStarted);
    void updateNotificationParams(in NotificationParams params);
    void startService(in VpnOptions options, in long runTime, in IResultInterface result);
    void stopService(in IResultInterface result);
    void setEventListener(in IEventInterface event);
    void setCrashlytics(in boolean enable);
    long getRunTime();
}