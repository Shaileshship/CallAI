package com.shailesh.callai

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.M)
object PhoneAccountManager {

    private const val ACCOUNT_LABEL = "Call-AI"

    fun registerPhoneAccount(context: Context) {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val componentName = ComponentName(context, CallConnectionService::class.java)
        
        val phoneAccountHandle = PhoneAccountHandle(componentName, ACCOUNT_LABEL)

        val phoneAccount = PhoneAccount.builder(phoneAccountHandle, ACCOUNT_LABEL)
            .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
            .build()
        
        telecomManager.registerPhoneAccount(phoneAccount)
    }

    fun getPhoneAccountHandle(context: Context): PhoneAccountHandle {
        val componentName = ComponentName(context, CallConnectionService::class.java)
        return PhoneAccountHandle(componentName, ACCOUNT_LABEL)
    }
} 