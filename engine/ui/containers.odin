package ui

import "engine:gfx"

container_linear :: proc(
	horizontal: bool,
	style: ^StyleClass = nil, 
	offsets: Maybe(BoxOffsets) = nil, 
	separation: Maybe(f32) = nil,
	box_style: Maybe(BoxStyle) = nil,
) {
	result: WithOverrides(ContainerLinearStyle)
	if offsets != nil {
		result.padding = offsets.?
		result.set_fields += {0}
	}
	if separation != nil {
		result.separation = separation.?
		result.set_fields += {1}
	}
	if box_style != nil {
		result.box_style = box_style.?
		result.set_fields += {2}
	}

	if horizontal {
		layout_container(Layout_Linear_Horizontal{}, result, style)
	} else {
		layout_container(Layout_Linear_Vertical{}, result, style)
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

