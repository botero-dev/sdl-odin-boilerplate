package ui

import "core:math"

import clay "../clay-odin"

RoundingPolicy :: enum {
    Round, // ties away from zero
    Floor, // 1.999 -> 1
    Ceil, // 1.001 -> 2
}

// Only well defined for positive values
scaling_apply :: proc "contextless" (policy: RoundingPolicy, value: f32) -> int {
    result: f32
    switch policy {
        case .Round:
            result = math.round(value)
        case .Floor:
            result = math.trunc(value)
        case .Ceil:
            result = math.ceil(value)
    }
    return int(result)
}


border_policy :: proc "contextless" (border: $T) -> u16 {
	return u16(scaling_apply(.Round, f32(border) * scale_factor)) // could also be ceil or floor
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

