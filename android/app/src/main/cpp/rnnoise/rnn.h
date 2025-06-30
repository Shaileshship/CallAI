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

#ifndef RNN_H
#define RNN_H

#include <stdlib.h>
#include <stdio.h>

#define RNN_EXPORT

typedef struct {
    int nb_inputs;
    int nb_neurons;
    int nb_outputs;
    const float *input_weights;
    const float *recurrent_weights;
    const float *output_weights;
    const float *input_bias;
    const float *neuron_bias;
    const float *output_bias;
    float *neurons;
} RNNState;

typedef struct {
    int input_dense_size;
    int input_dense_nb_inputs;
    const float *input_dense_weights;
    const float *input_dense_bias;
    int vad_gru_size;
    const float *vad_gru_weights;
    const float *vad_gru_bias;
    int noise_gru_size;
    const float *noise_gru_weights;
    const float *noise_gru_bias;
    int denoise_gru_size;
    const float *denoise_gru_weights;
    const float *denoise_gru_bias;
    int dense_size;
    int dense_nb_inputs;
    const float *dense_weights;
    const float *dense_bias;
} RNNModel;

#define RNN_ALLOC(type, count) ((type*)malloc(sizeof(type)*count))
#define RNN_FREE(ptr) (free(ptr))
#define RNN_COPY(dst, src, n) (memcpy(dst, src, (n)*sizeof(*(dst))))

void compute_rnn(RNNState *rnn, const float *in, float *out);

#endif 