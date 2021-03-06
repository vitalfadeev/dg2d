/**
  This module contains some helper functions for the blitter modules.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.blitex;

import dg2d.misc;
import dg2d.rasterizer;

private:

enum __m128i XMZERO = [0,0,0,0];
enum __m128i XMFFFF = [0xFFFF,0xFFFF,0xFFFF,0xFFFF];

public:

/**
  Calculate the gradient index for given repeat mode
*/

__m128i calcRepeatModeIDX(RepeatMode mode)(__m128i ipos, __m128i lutmsk, __m128i lutmsk2)
{
    static if (mode == RepeatMode.Repeat)
    {
        return ipos & lutmsk;
    }
    else static if (mode == RepeatMode.Pad)
    {
        ipos = ipos & _mm_cmpgt_epi32(ipos, XMZERO);
        return (ipos | _mm_cmpgt_epi32(ipos, lutmsk)) & lutmsk;
    }
    else
    {
        return (ipos ^ _mm_cmpgt_epi32(ipos & lutmsk2, lutmsk)) & lutmsk;
    }
}

/**
  broadcast alpha
  
  if x = [A1,R1,G1,B1,A0,R0,G0,B0], values in low 8 bits of each 16 bit element
  the result is [A1,A1,A1,A1,A0,A0,A0,A0], alpha in high 8 bits of each 16 bit element
*/

// shuffleVector version (commented out) should lower to pshufb, but it is a bit slower on
// my CPU, maybe from increased register pressure?

__m128i _mm_broadcast_alpha(__m128i x)
{
    x = _mm_shufflelo_epi16!255(x);
    x = _mm_shufflehi_epi16!255(x);
    return _mm_slli_epi16(x,8);
//    return  cast(__m128i)
//        shufflevector!(byte16, 7,6,7,6,7,6,7,6,  15,14,15,14,15,14,15,14)
//            (cast(byte16)a, cast(byte16)a);
}

/**
  calculate coverage from winding value
*/

int calcCoverage(WindingRule rule)(int winding)
{
    static if (rule == WindingRule.NonZero)
    {
        int tmp = abs(winding)*2;
        return (tmp > 0xFFFF) ? 0xFFFF : tmp;
    }
    else
    {
        short tmp = cast(short) winding;
        return (tmp ^ (tmp >> 15)) * 2;
    }
}

/**
  calculate coverage from winding value
*/

__m128i calcCoverage(WindingRule rule)(__m128i winding)
{
    static if (rule == WindingRule.NonZero)
    {
        __m128i mask = _mm_srai_epi32(winding,31); 
        __m128i tmp = _mm_add_epi32(winding,mask);
        tmp = _mm_xor_si128(tmp,mask);         // abs
        tmp = _mm_packs_epi32(tmp,XMZERO);     // saturate/pack to int16
        return _mm_slli_epi16(tmp, 1);         // << to uint16
    }
    else
    {
        __m128i tmp = _mm_and_si128(winding,XMFFFF); 
        __m128i mask = _mm_srai_epi16(tmp,15);  // mask
        tmp = _mm_xor_si128(tmp,mask);          // fold in halff
        tmp = _mm_packs_epi32(tmp,XMZERO);      // pack to int16
        return _mm_slli_epi16(tmp, 1);          // << to uint16
    } 
}