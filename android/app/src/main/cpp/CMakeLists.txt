cmake_minimum_required(VERSION 3.10)

project(rnnoise_jni)

add_library(
    rnnoise_jni SHARED
    rnnoise/denoise.c
    rnnoise/rnn.c
    rnnoise/kiss_fft.c
    rnnoise/pitch.c
    rnnoise/common.c
    jni-wrapper.cpp
)

target_include_directories(rnnoise_jni PUBLIC rnnoise)

find_library(log-lib log)
target_link_libraries(rnnoise_jni ${log-lib}) 