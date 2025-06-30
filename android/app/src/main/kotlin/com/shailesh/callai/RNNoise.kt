package com.shailesh.callai

object RNNoise {
    init {
        System.loadLibrary("rnnoise_jni")
    }

    external fun create(): Long
    external fun processFrame(state: Long, frame: ShortArray): Float
    external fun destroy(state: Long)
} 