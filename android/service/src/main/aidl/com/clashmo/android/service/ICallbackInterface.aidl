// ICallbackInterface.aidl
package com.clashmo.android.service;

import com.clashmo.android.service.IAckInterface;

interface ICallbackInterface {
    oneway void onResult(in byte[] data,in boolean isSuccess, in IAckInterface ack);
}