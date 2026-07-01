package ui

import "base:intrinsics"
import "core:math/linalg"
import "core:math"

import clay "../clay-odin"

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


DPI_ElementDeclaration :: proc "contextless" (
	decl: clay.ElementDeclaration,
) -> clay.ElementDeclaration {
	dpi := scale_factor
	result := decl
	result.cornerRadius = DPI_CornerRadius(decl.cornerRadius)
	result.border.width = DPI_BorderWidth(result.border.width)
	result.layout.padding = DPI_Padding(result.layout.padding)
	result.layout.childGap = border_policy(result.layout.childGap)
	result.floating.offset.x *= dpi
	result.floating.offset.y *= dpi

	if result.layout.sizing.width.type == .Fixed {
		result.layout.sizing.width.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.width.constraints.sizeMinMax.max *= dpi
	}
	if result.layout.sizing.height.type == .Fixed {
		result.layout.sizing.height.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.height.constraints.sizeMinMax.max *= dpi
	}

	return result
}

DPI :: DPI_ElementDeclaration


DPI_BorderWidth :: proc "contextless" (input: clay.BorderWidth) -> clay.BorderWidth {
	return clay.BorderWidth {
		border_policy(input.left),
		border_policy(input.right),
		border_policy(input.top),
		border_policy(input.bottom),
		border_policy(input.betweenChildren),
	}
}

DPI_CornerRadius :: proc "contextless" (radii: clay.CornerRadius) -> clay.CornerRadius {
	dpi := scale_factor
	return clay.CornerRadius {
		dpi * (radii.topLeft),
		dpi * (radii.topRight),
		dpi * (radii.bottomLeft),
		dpi * (radii.bottomRight),
	}
}

DPI_Padding :: proc "contextless" (padding: clay.Padding) -> clay.Padding {
	return clay.Padding {
		border_policy(padding.left),
		border_policy(padding.right),
		border_policy(padding.top),
		border_policy(padding.bottom),
	}
}

