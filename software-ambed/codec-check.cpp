// SPDX-License-Identifier: GPL-3.0-or-later
#include <cmath>
#include <chrono>
#include <iostream>
#include "mbe/mbevocoder.h"
int main() {
    for (int direction = 0; direction < 2; ++direction) {
        MBEVocoder source, decoder, encoder, receiver;
        auto start = std::chrono::steady_clock::now();
        double energy = 0;
        for (int frame = 0; frame < 200; ++frame) {
            int16_t pcm[160], intermediate[160] = {}, output[160] = {};
            uint8_t a[9] = {}, b[9] = {};
            for (int i = 0; i < 160; ++i) pcm[i] = 10000 * std::sin(2 * 3.141592653589793 * 220 * (frame*160+i) / 8000);
            if (direction == 0) {
                source.encode_2400x1200(pcm, a); decoder.decode_2400x1200(intermediate, a);
                encoder.encode_2450x1150(intermediate, b); receiver.decode_2450x1150(output, b);
            } else {
                source.encode_2450x1150(pcm, a); decoder.decode_2450x1150(intermediate, a);
                encoder.encode_2400x1200(intermediate, b); receiver.decode_2400x1200(output, b);
            }
            for (auto sample : output) energy += double(sample)*sample;
        }
        double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now()-start).count();
        std::cout << (direction ? "DMR -> D-Star" : "D-Star -> DMR") << ": 200 frames, "
                  << ms << " ms, decoded RMS " << std::sqrt(energy/32000) << '\n';
        if (energy < 1) return 1;
    }
}
