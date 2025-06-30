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
   NEGLIGENCE OR OTHERWISE) ARISING IN A
*/

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <math.h>
#include "kiss_fft.h"
#include "common.h"
#include "arch.h"
#include "pitch.h"
#include "arch.h"
#include <stdio.h>

#define PITCH_MIN_PERIOD 40
#define PITCH_MAX_PERIOD 160
#define PITCH_FRAME_SIZE (PITCH_MAX_PERIOD+PITCH_FRAME_SIZE_PADDED)
#define PITCH_FRAME_SIZE_PADDED 32

void compute_pitch_xcorr(const float *x, float *xcorr)
{
    int i, j;
    float sum[PITCH_MAX_PERIOD-PITCH_MIN_PERIOD+1] = {0};
    for (i=0;i<PITCH_MAX_PERIOD-PITCH_MIN_PERIOD+1;i++)
    {
        for (j=0;j<PITCH_FRAME_SIZE-PITCH_MAX_PERIOD;j++)
        {
            sum[i] += x[j]*x[j+i+PITCH_MIN_PERIOD];
        }
    }
    for (i=0;i<PITCH_MAX_PERIOD-PITCH_MIN_PERIOD+1;i++) xcorr[i] = sum[i];
} 