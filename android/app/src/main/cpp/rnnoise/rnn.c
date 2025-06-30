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
#include "rnn.h"
#include "arch.h"
#include "rnn_data.h"

void compute_rnn(RNNState *rnn, const float *in, float *out)
{
    int i, j;
    float dense_out[rnn->nb_neurons];
    float recurrent_out[rnn->nb_neurons];
    /* Compute dense layer */
    for (i=0;i<rnn->nb_neurons;i++)
    {
        float sum = rnn->input_bias[i];
        for (j=0;j<rnn->nb_inputs;j++)
            sum += rnn->input_weights[i*rnn->nb_inputs + j]*in[j];
        dense_out[i] = tanhf(sum);
    }
    /* Compute recurrent layer */
    for (i=0;i<rnn->nb_neurons;i++)
    {
        float sum = rnn->neuron_bias[i];
        for (j=0;j<rnn->nb_neurons;j++)
            sum += rnn->recurrent_weights[i*rnn->nb_neurons + j]*rnn->neurons[j];
        recurrent_out[i] = tanhf(sum);
    }
    for (i=0;i<rnn->nb_neurons;i++)
        rnn->neurons[i] = dense_out[i] + recurrent_out[i];
    /* Compute output layer */
    for (i=0;i<rnn->nb_outputs;i++)
    {
        float sum = rnn->output_bias[i];
        for (j=0;j<rnn->nb_neurons;j++)
            sum += rnn->output_weights[i*rnn->nb_neurons + j]*rnn->neurons[j];
        out[i] = 1.f/(1.f + expf(-sum));
    }
} 