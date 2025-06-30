/* Copyright (c) 2018, Jean-Marc Valin */
/*
   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

   - Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef RNNOISE_H
#define RNNOISE_H

#include <stdio.h>

#define RNNOISE_EXPORT

#ifdef __cplusplus
extern "C" {
#endif

/** Opaque state for the denoiser */
typedef struct DenoiseState DenoiseState;

/**
 * Creates a denoiser state.
 *
 * @param[in] model If `NULL`, uses the default model.
 * @return A denoiser state.
 */
RNNOISE_EXPORT DenoiseState *rnnoise_create(void *model);

/**
 * Destroys a denoiser state.
 *
 * @param[in] st The denoiser state to destroy.
 */
RNNOISE_EXPORT void rnnoise_destroy(DenoiseState *st);

/**
 * Processes a frame of audio for denoising.
 *
 * @param[in] st The denoiser state.
 * @param[out] out The denoised audio frame (16-bit PCM).
 * @param[in] in The input audio frame (16-bit PCM).
 * @return The voice activity probability.
 */
RNNOISE_EXPORT float rnnoise_process_frame(DenoiseState *st, short *out, const short *in);

#ifdef __cplusplus
}
#endif

#endif 