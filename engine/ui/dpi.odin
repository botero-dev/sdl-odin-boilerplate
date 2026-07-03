package ui

import "base:intrinsics"
import "core:math/linalg"
import "core:math"


ScalingPolicy :: enum {
	Apply,
	Ignore,
}

RoundingPolicy :: enum {
	Round,  // ties away from zero
	Ignore, // keep decimal value
	Floor,  // 1.999 -> 1
	Ceil,   // 1.001 -> 2
}

BorderFlags :: bit_field(u8) {
	scaling: ScalingPolicy   | 1,
	rounding: RoundingPolicy | 7,
}

scale_factor: f32 = 1

scaling_apply :: proc "contextless" (value: $T) -> f32 {

	return f32(value) * scale_factor
}

border_apply :: proc "contextless" (flags: BorderFlags, value: $T) -> f32 where intrinsics.type_is_numeric(T) {
	result := f32(value)
	if flags.scaling == .Apply {
		result = result * scale_factor
	}
	switch flags.rounding {
		case .Ignore:
			// do nothing
		case .Round:
			result = math.round(result)
		case .Floor:
			result = math.trunc(result)
		case .Ceil:
			result = math.ceil(result)
	}
	return result
}

border_apply_arr :: proc "contextless" (flags: BorderFlags, value: $T, $size: int) -> T {
	result := transmute([size]f32)value
	if flags.scaling == .Apply {
		result = result * scale_factor
	}
	switch flags.rounding {
		case .Ignore:
			// do nothing
		case .Round:
			result = linalg.round(result)
		case .Floor:
			result = linalg.trunc(result)
		case .Ceil:
			result = linalg.ceil(result)
	}
	return transmute(T)result
}


// Only well defined for positive values
scaling_apply_rounded :: proc "contextless" (policy: RoundingPolicy, value: $T) -> f32 {
	result: f32 = scaling_apply(value)
	switch policy {
		case .Ignore:
			// do nothing
		case .Round:
			result = math.round(result)
		case .Floor:
			result = math.trunc(result)
		case .Ceil:
			result = math.ceil(result)
	}
	return result
}


border_policy :: proc "contextless" (border: $T) -> u16 {
	return u16(scaling_apply_rounded(.Round, f32(border))) // could also be ceil or floor
}
