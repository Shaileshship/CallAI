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

#ifndef COMMON_H
#define COMMON_H

#include "arch.h"
#include "rnn.h"
#include "kiss_fft.h"

#define FRAME_SIZE 480
#define NB_BANDS 22

#define NOISE_FLOOR .001f
#define ACTIVITY_FLOOR .02f

#define B_SMOOTH .05f
#define G_SMOOTH .2f
#define A_SMOOTH .95f
#define A_DECAY .99f

#define PREEMPH .0f

#define LP_GAIN .99f
#define HP_GAIN .9f

typedef struct {
    float noise_std[NB_BANDS];
    float speech_std[NB_BANDS];
    float features[NB_BANDS+1];
    RNNState rnn;
    float vad_prob;
    float gain_lp[NB_BANDS];
} DenoiseStateInternal;

void compute_band_energy(float *bandE, const kiss_fft_cpx *X);

void apply_window(float *x);

void forward_transform(kiss_fft_cpx *X, const float *x);

void inverse_transform(float *x, const kiss_fft_cpx *X);

#endif 