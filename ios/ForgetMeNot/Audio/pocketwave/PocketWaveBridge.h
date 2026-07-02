/* Bridging header: exposes the vendored PocketWave FM synth to Swift.
 * fm-synth.h pulls in instruments.h + presets.h itself; osc.h first for the
 * osc_write_* helpers its status functions reference. */
#ifndef POCKETWAVE_BRIDGE_H
#define POCKETWAVE_BRIDGE_H
#include "osc.h"
#include "json-helpers.h"
#include "fm-synth.h"

/* PRESET_NAMES is a C array of pointers — clumsy to index from Swift. */
static inline const char *pw_preset_name(int idx) {
    if (idx < 0) idx = -idx;
    return PRESET_NAMES[idx % NUM_PRESETS];
}
#endif
