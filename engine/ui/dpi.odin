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
scale_factor_user: f32 = 1
scale_factor_window: f32 = 1

scaling_set_factor :: proc (value: f32) {
	scale_factor_user = value
}

scaling_logical_to_pixels :: proc (logical_size: [2]f32, scale: f32) -> [2]i32 {
	assert(scale != 0)
	return {
		i32(logical_size.x * scale + 0.5), // round, tie towards zero
		i32(logical_size.y * scale + 0.5),
	}
}

scaling_pixels_to_logical :: proc (pixel_size: [2]i32, scale: f32) -> [2]f32 {
	assert(scale != 0)
	return {
		f32(pixel_size.x) / scale,
		f32(pixel_size.y) / scale,
	}
}

scaling_apply_value :: proc "contextless" (value: $T) -> f32 {

	return f32(value) * scale_factor
}

scaling_apply :: proc {
	scaling_apply_value,
	scaling_apply_rounded,
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

// available user scaling factors, stepped through with Ctrl+= / Ctrl+-
dpi_index := 4
dpi_levels := []f32{0.5, 0.66666666666666, 0.8, 0.9, 1, 1.1, 1.25, 1.3333333333333, 1.5, 2, 2.5, 3, 4}

dpi_offset :: proc(offset: int) {
	dpi_index = clamp(dpi_index + offset, 0, len(dpi_levels) - 1)
	scaling_set_factor(dpi_levels[dpi_index])
}
