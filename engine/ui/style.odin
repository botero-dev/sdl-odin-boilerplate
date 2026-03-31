package ui

import clay "../clay-odin"

Style :: struct {

}

StyleClass :: struct {
	class: string,
	variant: string,
	//id: u32,
	id: StyleKey,
}

Color :: [4]f32

CornerRadii :: struct {
	nw: f32,
	ne: f32,
	se: f32,
	sw: f32,
}

BoxOffsets :: struct {
	left: f32,
	right: f32,
	top: f32,
	bottom: f32,
}

RectStyle :: struct {
	padding: BoxOffsets,
}


ContainerStyle :: struct {
	using base_rect: RectStyle,
	separation: f32,
}


BoxStyleBase :: struct {
	using base_rect: RectStyle,
	draw_offset: BoxOffsets,
}

BoxStyleTexturedMapping :: enum {
	Normal,
	Tiled,
	SlicedScale,
	SlicedRepeat,
}

BoxStyleTextured :: struct {
	using base_box: BoxStyleBase,
	texture_id: u32,
	mapping: BoxStyleTexturedMapping,
	transform: [4]f32, // x, y, scalex, scaley
	// tint color?
	// blend mode?
}


BoxStyleColored :: struct {
	using base: BoxStyleBase,
	background: Color,
	border_color: Color,
	border_width: BoxOffsets,
	corner_radii: CornerRadii,
	// blendmode?
}

BoxStyle :: union {
	BoxStyleColored,
	BoxStyleTextured,
}

ButtonStyle :: struct {
	idle_box: BoxStyle,
	hover_box: BoxStyle,
	pressed_box: BoxStyle,
	disabled_box: BoxStyle,
	idle_text: TextStyle,
	hover_text: TextStyle,
	pressed_text: TextStyle,
	disabled_text: TextStyle,
}

TextStyle :: struct {
	using config: clay.TextElementConfig
	/* // maybe use these in the future:
	color: Color,
	font: i32,
	size: f32,
	modifier: i32, // future bitmask for black/italics/underline/strikethrough
	*/
}


style_class :: proc "contextless" (in_class: string, in_variant: string = "") -> StyleClass {
	return StyleClass{
		class = in_class,
		variant = in_variant,
		id = {},
	}
}

// [class, variant]
StyleKey :: struct {
	class_idx: i32,
	variant_idx: i32,
}

StyleDirectory :: struct {
	//slots: [dynamic]StyleKey,
	classes_types: [dynamic]typeid,
	classes_names: map[string]i32,
	containers: [dynamic]^StyleContainerBase,
}

StyleContainerBase :: struct {
	labels: map[string]int,
}

StyleContainer :: struct($T: typeid) {
	using base: StyleContainerBase,
	styles: [dynamic]T,
}


push_style :: proc(class: ^StyleClass, style: $T) {

	// if len(style_directory.slots) == 0 {
	//     append(&style_directory.slots, {})
	// }

	if len(style_directory.classes_types) == 0 {
		 append(&style_directory.classes_types, nil)
		 append(&style_directory.containers, nil)
	}
	
	class_type := typeid_of(T)
	class_idx, class_found := style_directory.classes_names[class.class]
	if class_found {
		assert(class_type == style_directory.classes_types[class_idx])
	} else {
		class_idx = i32(len(style_directory.classes_types))
		style_directory.classes_names[class.class] = class_idx
		class.id.class_idx = class_idx
		append(&style_directory.classes_types, class_type)
		container: = new(StyleContainer(T))
		append(&style_directory.containers, container)
	}

	container := (^StyleContainer(T))( style_directory.containers[class_idx])

	existing_style, style_found := container.labels[class.variant]
	if style_found {
		container.styles[existing_style] = style
	} else {
		container.labels[class.variant] = len(container.styles)
		append(&container.styles, style)
	}
}


style_directory: StyleDirectory

setup_directory :: proc() {

	btn_style := ButtonStyle{}
	btn_style.idle_box = BoxStyleColored{
		background = {1, 0, 0, 1},
		border_color = {0, 1, 0, 1},
		border_width = {2, 2, 2, 2},
		padding = {12, 12, 4, 4},
	}
	c := style_class("Button")
	push_style(&c, btn_style)

	container_style_base := ContainerStyle {
		padding = {4, 4, 4, 4},
		separation = 4,
	}
	cont_base := style_class("Container")
	push_style(&cont_base, container_style_base)

	container_style_tight := ContainerStyle {
		padding = {4, 4, 4, 4},
		separation = 4,
	}
	cont_tight := style_class("Container", "tight")
	push_style(&cont_tight, container_style_tight)

	

}


resolve_class :: proc(class: ^StyleClass) {
	if len(style_directory.classes_types) == 0 {
		// placeholder for now
		setup_directory()
	}

	class_idx, found := style_directory.classes_names[class.class]
	assert(found)
	class.id.class_idx = class_idx

	container := style_directory.containers[class_idx]
	variant_idx, found2 := container.labels[class.variant]
	assert(found2)
	class.id.variant_idx = i32(variant_idx)

}


get_current_style :: proc(class: ^StyleClass, $T: typeid) -> ^T {
	if class.id == {} {
		resolve_class(class)
	}
	id := class.id
	
	assert(style_directory.classes_types[id.class_idx] == typeid_of(T))

	container := (^StyleContainer(T))(style_directory.containers[id.class_idx])
	style := &container.styles[id.variant_idx]

	return style
}