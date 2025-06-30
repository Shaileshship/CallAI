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

#ifndef ARCH_H
#define ARCH_H

#include <math.h>

#define OPUS_INLINE inline

#if defined(__GNUC__)
#  define OPUS_GCC_PREREQ(major, minor) \
    (__GNUC__ > (major) || (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#else
#  define OPUS_GCC_PREREQ(major, minor) (0)
#endif

#ifndef OVERRIDE_OPUS_MAX16
#define OPUS_MAX16(a, b) ((a) > (b) ? (a) : (b))
#endif

#ifndef OVERRIDE_OPUS_MIN16
#define OPUS_MIN16(a, b) ((a) < (b) ? (a) : (b))
#endif

#ifndef OVERRIDE_OPUS_MAX32
#define OPUS_MAX32(a, b) ((a) > (b) ? (a) : (b))
#endif

#ifndef OVERRIDE_OPUS_MIN32
#define OPUS_MIN32(a, b) ((a) < (b) ? (a) : (b))
#endif

#ifndef OVERRIDE_OPUS_CLAMP16
#define OPUS_CLAMP16(x, a, b) (OPUS_MAX16(a, OPUS_MIN16(b, x)))
#endif

#define IMUL32(a, b) ((a)*(b))

#define SATURATE16(x) (OPUS_CLAMP16(x, -32768, 32767))

#endif 