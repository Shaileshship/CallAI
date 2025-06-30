/* Copyright (c) 2017, Jean-Marc Valin */
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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <math.h>
#include <stdio.h>
#include "rnnoise.h"
#include "common.h"
#include "arch.h"
#include "pitch.h"
#include "kiss_fft.h"
#include "rnn.h"
#include <stdlib.h>
#include <string.h>

#define FRAME_SIZE 480

#define NB_BANDS 22

#define VAD_THESHOLD .8f

#define NOISE_FLOOR .001f
#define ACTIVITY_FLOOR .02f

#define B_SMOOTH .05f
#define G_SMOOTH .2f
#define A_SMOOTH .95f
#define A_DECAY .99f

#define PREEMPH .0f

#define LP_GAIN .99f
#define HP_GAIN .9f

struct DenoiseState {
    DenoiseStateInternal internal;
};

DenoiseState *rnnoise_create(void *model) {
    DenoiseState *st = malloc(sizeof(DenoiseState));
    memset(&st->internal, 0, sizeof(DenoiseStateInternal));
    return st;
}

void rnnoise_destroy(DenoiseState *st) {
    free(st);
}

float rnnoise_process_frame(DenoiseState *st, short *out, const short *in) {
    int i;
    float x[FRAME_SIZE];
    kiss_fft_cpx X[FRAME_SIZE];
    kiss_fft_cpx P[NB_BANDS];
    float Ex[NB_BANDS], Ep[NB_BANDS];
    float g[NB_BANDS];
    
    for (i=0;i<FRAME_SIZE;i++)
        x[i] = in[i];
    apply_window(x);
    forward_transform(X, x);
    compute_band_energy(Ex, X);

    DenoiseStateInternal *internal = &st->internal;
    // Process frame using internal state
    for (i=0;i<NB_BANDS;i++) {
        P[i].r *= g[i];
        P[i].i *= g[i];
    }
    inverse_transform(x, P);
    for (i=0;i<FRAME_SIZE;i++)
        out[i] = SATURATE16(x[i]);
    return internal->vad_prob;
}

static const float band_gains[NB_BANDS] = {1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, 1.f, .8f, .7f, .6f, .5f, .4f, .3f, .2f, .1f, .05f};
/* This is the window used by the L_ LPC function in the full-band codec. */
static const float analysis_window[FRAME_SIZE] = {
   0.00000000e+00f,   0.00000000e+00f,   0.00000000e+00f,   0.00000000e+00f
}; 