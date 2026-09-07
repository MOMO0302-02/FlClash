// IEventInterface.aidl
package com.clashmo.android.service;

import com.clashmo.android.service.IAckInterface;

interface IEventInterface {
    oneway void onEvent(in String id, in byte[] data,in boolean isSuccess, in IAckInterface ack);
}