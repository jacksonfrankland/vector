// This file contains code from the gonum repository:
// https://github.com/gonum/gonum/blob/master/internal/asm/f64/axpyunitaryto_amd64.s
// it is distributed under the 3-Clause BSD license:
//
// Copyright ©2013 The Gonum Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the Gonum project nor the names of its authors and
//       contributors may be used to endorse or promote products derived from this
//       software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// +build !noasm

#include "textflag.h"

#define MOVDDUP_ALPHA    LONG $0x44120FF2; WORD $0x2024 // @ MOVDDUP 32(SP), X0  /*XMM0, 32[RSP]*/

#define X_PTR SI
#define DST_PTR DI
#define IDX AX
#define LEN CX
#define TAIL BX
#define ALPHA X0
#define ALPHA_2 X1

// func scalUnitaryTo(dst []float64, alpha float64, x []float64)
// This function assumes len(dst) >= len(x).
TEXT ·scalUnitaryTo(SB), NOSPLIT, $0
	MOVQ x_base+32(FP), X_PTR    // X_PTR = &x
	MOVQ dst_base+0(FP), DST_PTR // DST_PTR = &dst
	MOVDDUP_ALPHA                // ALPHA = { alpha, alpha }
	MOVQ x_len+40(FP), LEN       // LEN = len(x)
	CMPQ LEN, $0
	JE   end                     // if LEN == 0 { return }

	XORQ IDX, IDX   // IDX = 0
	MOVQ LEN, TAIL
	ANDQ $7, TAIL   // TAIL = LEN % 8
	SHRQ $3, LEN    // LEN = floor( LEN / 8 )
	JZ   tail_start // if LEN == 0 { goto tail_start }

	MOVUPS ALPHA, ALPHA_2 // ALPHA_2 = ALPHA for pipelining

loop:  // do { // dst[i] = alpha * x[i] unrolled 8x.
	MOVUPS (X_PTR)(IDX*8), X2   // X_i = x[i]
	MOVUPS 16(X_PTR)(IDX*8), X3
	MOVUPS 32(X_PTR)(IDX*8), X4
	MOVUPS 48(X_PTR)(IDX*8), X5

	MULPD ALPHA, X2   // X_i *= ALPHA
	MULPD ALPHA_2, X3
	MULPD ALPHA, X4
	MULPD ALPHA_2, X5

	MOVUPS X2, (DST_PTR)(IDX*8)   // dst[i] = X_i
	MOVUPS X3, 16(DST_PTR)(IDX*8)
	MOVUPS X4, 32(DST_PTR)(IDX*8)
	MOVUPS X5, 48(DST_PTR)(IDX*8)

	ADDQ $8, IDX  // i += 8
	DECQ LEN
	JNZ  loop     // while --LEN > 0
	CMPQ TAIL, $0
	JE   end      // if TAIL == 0 { return }

tail_start: // Reset loop counters
	MOVQ TAIL, LEN // Loop counter: LEN = TAIL
	SHRQ $1, LEN   // LEN = floor( TAIL / 2 )
	JZ   tail_one  // if LEN == 0 { goto tail_one }

tail_two: // do {
	MOVUPS (X_PTR)(IDX*8), X2   // X_i = x[i]
	MULPD  ALPHA, X2            // X_i *= ALPHA
	MOVUPS X2, (DST_PTR)(IDX*8) // dst[i] = X_i
	ADDQ   $2, IDX              // i += 2
	DECQ   LEN
	JNZ    tail_two             // while --LEN > 0

	ANDQ $1, TAIL
	JZ   end      // if TAIL == 0 { return }

tail_one:
	MOVSD (X_PTR)(IDX*8), X2   // X_i = x[i]
	MULSD ALPHA, X2            // X_i *= ALPHA
	MOVSD X2, (DST_PTR)(IDX*8) // dst[i] = X_i

end:
	RET
