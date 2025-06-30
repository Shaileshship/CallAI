#include "common.h"
#include "kiss_fft.h"
#include <math.h>

static kiss_fft_cfg fft_forward;
static kiss_fft_cfg fft_inverse;

void compute_band_energy(float *bandE, const kiss_fft_cpx *X) {
    int i;
    for (i = 0; i < NB_BANDS; i++) {
        bandE[i] = X[i].r * X[i].r + X[i].i * X[i].i;
    }
}

void apply_window(float *x) {
    int i;
    for (i = 0; i < FRAME_SIZE; i++) {
        x[i] *= 0.5f * (1.0f - cosf((2.0f * M_PI * i) / (FRAME_SIZE - 1)));
    }
}

void forward_transform(kiss_fft_cpx *X, const float *x) {
    if (!fft_forward) {
        fft_forward = kiss_fft_alloc(FRAME_SIZE, 0, NULL, NULL);
    }
    kiss_fft_cpx in[FRAME_SIZE];
    int i;
    for (i = 0; i < FRAME_SIZE; i++) {
        in[i].r = x[i];
        in[i].i = 0;
    }
    kiss_fft(fft_forward, in, X);
}

void inverse_transform(float *x, const kiss_fft_cpx *X) {
    if (!fft_inverse) {
        fft_inverse = kiss_fft_alloc(FRAME_SIZE, 1, NULL, NULL);
    }
    kiss_fft_cpx out[FRAME_SIZE];
    kiss_fft(fft_inverse, X, out);
    int i;
    for (i = 0; i < FRAME_SIZE; i++) {
        x[i] = out[i].r / FRAME_SIZE;
    }
} 