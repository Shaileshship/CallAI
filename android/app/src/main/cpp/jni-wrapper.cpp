#include <jni.h>
#include "rnnoise.h"

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_shailesh_callai_RNNoise_create(JNIEnv *env, jobject thiz) {
    return (jlong) rnnoise_create(NULL);
}

JNIEXPORT jfloat JNICALL
Java_com_shailesh_callai_RNNoise_processFrame(JNIEnv *env, jobject thiz, jlong state, jshortArray frame) {
    jshort *frame_ptr = env->GetShortArrayElements(frame, NULL);
    float vad_prob = rnnoise_process_frame((DenoiseState *) state, frame_ptr, frame_ptr);
    env->ReleaseShortArrayElements(frame, frame_ptr, 0);
    return vad_prob;
}

JNIEXPORT void JNICALL
Java_com_shailesh_callai_RNNoise_destroy(JNIEnv *env, jobject thiz, jlong state) {
    rnnoise_destroy((DenoiseState *) state);
}

} 