package ui

import "engine:gfx"

container_linear :: proc(
	horizontal: bool,
	style: ^StyleClass = nil, 
	offsets: Maybe(BoxOffsets) = nil, 
	separation: Maybe(f32) = nil,
	box_style: Maybe(BoxStyle) = nil,
) {
	overrides: WithOverrides(ContainerLinearStyle)
	if offsets != nil {
		overrides.padding = offsets.?
		overrides.set_fields += {0}
	}
	if separation != nil {
		overrides.separation = separation.?
		overrides.set_fields += {1}
	}
	if box_style != nil {
		overrides.box_style = box_style.?
		overrides.set_fields += {2}
	}

	if horizontal {
		layout_container(Layout_Linear_Horizontal{}, overrides, style)
	} else {
		layout_container(Layout_Linear_Vertical{}, overrides, style)
	}
	
}

@(deferred_none=layout_close)
container_vertical :: proc(
	style: ^StyleClass = nil, 
	offsets: Maybe(BoxOffsets) = nil, 
	separation: Maybe(f32) = nil,
	box_style: Maybe(BoxStyle) = nil,
) {
	container_linear(false, style, offsets, separation, box_style)
}

@(deferred_none=layout_close)
container_horizontal :: proc(
	style: ^StyleClass = nil, 
	offsets: Maybe(BoxOffsets) = nil, 
	separation: Maybe(f32) = nil,
	box_style: Maybe(BoxStyle) = nil,
) {
	container_linear(true, style, offsets, separation, box_style)
}

