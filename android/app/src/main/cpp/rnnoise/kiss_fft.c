/*
Copyright (c) 2003-2010, Mark Borgerding

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the Mark Borgerding nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "_kiss_fft_guts.h"
#include <string.h>
#include <math.h>

kiss_fft_cfg kiss_fft_alloc(int nfft, int inverse_fft, void *mem, size_t *lenmem) {
    kiss_fft_cfg st = NULL;
    size_t memneeded = sizeof(struct kiss_fft_state) + sizeof(kiss_fft_cpx) * (nfft - 1);

    if (lenmem == NULL) {
        st = (kiss_fft_cfg) malloc(memneeded);
    } else {
        if (mem != NULL && *lenmem >= memneeded)
            st = (kiss_fft_cfg) mem;
        *lenmem = memneeded;
    }
    if (st) {
        int i;
        st->nfft = nfft;
        st->inverse = inverse_fft;

        for (i = 0; i < nfft; ++i) {
            const double pi = 3.141592653589793238462643383279502884197169399375105820974944;
            double phase = -2 * pi * i / nfft;
            if (st->inverse)
                phase *= -1;
            st->twiddles[i].r = (float) cos(phase);
            st->twiddles[i].i = (float) sin(phase);
        }
    }
    return st;
}

void kiss_fft_stride(kiss_fft_cfg st, const kiss_fft_cpx *fin, kiss_fft_cpx *fout, int in_stride) {
    int i, j;
    if (fin == fout) {
        // NOTE: this is not supporting in-place FFT
        return;
    }
    
    // Copy input to output
    for (i = 0; i < st->nfft; i++) {
        fout[i] = fin[i * in_stride];
    }

    // Perform FFT
    for (i = 0; i < st->nfft; i++) {
        kiss_fft_cpx sum = {0, 0};
        for (j = 0; j < st->nfft; j++) {
            float phase = 2 * M_PI * i * j / st->nfft;
            kiss_fft_cpx twiddle;
            twiddle.r = cosf(phase);
            twiddle.i = -sinf(phase);
            float real = fout[j].r * twiddle.r - fout[j].i * twiddle.i;
            float imag = fout[j].r * twiddle.i + fout[j].i * twiddle.r;
            sum.r += real;
            sum.i += imag;
        }
        fout[i] = sum;
    }

    if (st->inverse) {
        // Scale for inverse FFT
        for (i = 0; i < st->nfft; i++) {
            fout[i].r /= st->nfft;
            fout[i].i /= st->nfft;
        }
    }
}

void kiss_fft(kiss_fft_cfg cfg, const kiss_fft_cpx *fin, kiss_fft_cpx *fout) {
    kiss_fft_stride(cfg, fin, fout, 1);
}

void kiss_fft_free(const void *cfg) {
    free((void*)cfg);
}

/*
// ... existing code ...
    }
    kiss_fft_free(st);
}
*/ 