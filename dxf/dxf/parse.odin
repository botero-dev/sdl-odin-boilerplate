package dxf

import "core:fmt"
import "core:log"
import "core:strings"
import "core:strconv"
import "core:mem"
import "core:math"
import "core:math/linalg"


DXF_Code :: distinct u32
DXF_Group :: string

DXF_ARC :: DXF_Group("ARC")
DXF_CIRCLE :: DXF_Group("CIRCLE")
DXF_DIMENSION :: DXF_Group("DIMENSION")
DXF_ELLIPSE :: DXF_Group("ELLIPSE")
DXF_ENDSEC :: DXF_Group("ENDSEC")
DXF_ENTITIES :: DXF_Group("ENTITIES")
DXF_EOF :: DXF_Group("EOF")
DXF_INSERT :: DXF_Group("INSERT")
DXF_LINE :: DXF_Group("LINE")
DXF_LWPOLYLINE :: DXF_Group("LWPOLYLINE")
DXF_MTEXT :: DXF_Group("MTEXT")
DXF_SECTION :: DXF_Group("SECTION")
DXF_SPLINE :: DXF_Group("SPLINE")
DXF_TEXT :: DXF_Group("TEXT")
DXF_VIEWPORT :: DXF_Group("VIEWPORT")

DXF_Entity_Type :: enum {
	None,
	Section,
	Spline,
}

DXF_ParseState :: struct {
	start: ^byte,
	end: ^byte,
	cursor: ^byte,
}

DXF_Data :: struct {
	polylines: [dynamic]DXF_Polyline,
	splines: [dynamic]DXF_Spline,
    lines: [dynamic]DXF_Line,
    circles: [dynamic]DXF_Circle,
    texts: [dynamic]DXF_Text,


	curr_entity_type: DXF_Entity_Type,
	curr_entity_raw: string,
	curr_handle: string,
	curr_entity_id: uint,
	curr_knot: uint,
	curr_control_point: uint,

	curr_flags_70: u8,
	curr_i8_280: i8,
	curr_102_appdefined_group: string,
	curr_90_value_size: i32,
	curr_140_value_double: f64,
}

f64x2 :: [2]f64
f64x3 :: [3]f64
DXF_Line :: struct {
	start: f64x3,
	end: f64x3,
}


DXF_Circle :: struct {
	center: f64x3,
	radius: f64,
}



DXF_Polyline :: struct {
	points: []f64x2,
	bulges: []f64,
}

DXF_Spline :: struct {
	flags: uint,
	degree: uint,
	knots: []f64,
	control_points: []f64x3,
}


DXF_Text :: struct {
	content: string,
	pos: f64x3,
	end: f64x3,
}

DXF_Viewport :: struct {
	center: f64x3,
	size: f64x2,
}

PARSE_DEBUG :: false


parse_dxf :: proc(bytes: []byte) -> DXF_Data {

	parse_state_data := DXF_ParseState {
		start = &bytes[0],
		end = &(([^]byte)(&bytes[0])[len(bytes)]), // way to address past end
		cursor = &bytes[0]
	}

	parse_state := &parse_state_data

	entity_id := -1
	entity_type := DXF_Entity_Type.None

	data_data: DXF_Data
	data := &data_data

	for parse_state.cursor < parse_state.end {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if content == DXF_SECTION {
			parse_section(parse_state, data)
			continue
		} else if content == DXF_EOF {
			break
		}
		assert(false, "shouldn't reach this")
	}

	return data_data
}

parse_section :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {

	assert(parse_group_code(parse_state) == 2)
	section_name := parse_content_string(parse_state)

	if section_name == DXF_ENTITIES {
		parse_section_entities(parse_state, data)
		return
	}
	log.info("Parsing SECTION:", section_name)

	// any other section just iterates to the ENDSEC token
	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_ENDSEC {
				break
			}
			//continue
		}
		//log.info("code:", group_code, " :", content)
	}

	log.info("Finished SECTION:", section_name)
}


parse_section_entities :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	log.info("Parsing ENTITIES")


	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_ENDSEC {
				break
			}
			if content == DXF_SPLINE {
				parse_entity_spline(parse_state, data)
				continue
			}
			if content == DXF_LINE {
				parse_entity_line(parse_state, data)
				continue
			}
			if content == DXF_CIRCLE {
				parse_entity_circle(parse_state, data)
				continue
			}
			if content == DXF_LWPOLYLINE {
				parse_entity_polyline(parse_state, data)
				continue
			}
			if content == DXF_TEXT {
				parse_entity_text(parse_state, data)
				continue
			}
			if content == DXF_MTEXT {
				parse_entity_mtext(parse_state, data)
				continue
			}
			if content == DXF_VIEWPORT {
				parse_entity_viewport(parse_state, data)
				continue
			}
			if content == DXF_DIMENSION {
				parse_entity_dimension(parse_state, data)
				continue
			}
			if content == DXF_ARC {
				parse_entity_arc(parse_state, data)
				continue
			}
			if content == DXF_INSERT {
				parse_entity_insert(parse_state, data)
				continue
			}
			if content == DXF_ELLIPSE {
				parse_entity_ellipse(parse_state, data)
				continue
			}
			
			fmt.println("unhandled entity:", content)
		}
		fmt.println(group_code, ":", content)
	}

	log.info("Finished parsing ENTITIES")
}

parse_entity_ellipse :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	parse_header(parse_state, data)
	parse_code_assert_ignore(parse_state, DXF_Code(10), "center_y")
	parse_code_assert_ignore(parse_state, DXF_Code(20), "center_y")
	parse_code_assert_ignore(parse_state, DXF_Code(30), "center_z")

	parse_code_assert_ignore(parse_state, DXF_Code(11), "axis_x")
	parse_code_assert_ignore(parse_state, DXF_Code(21), "axis_y")
	parse_code_assert_ignore(parse_state, DXF_Code(31), "axis_z")

	parse_code_assert_ignore(parse_state, DXF_Code(210), "normal_x")
	parse_code_assert_ignore(parse_state, DXF_Code(220), "normal_y")
	parse_code_assert_ignore(parse_state, DXF_Code(230), "normal_z")

	parse_code_assert_ignore(parse_state, DXF_Code(40), "axis ratio")
	parse_code_assert_ignore(parse_state, DXF_Code(41), "arc_start")
	parse_code_assert_ignore(parse_state, DXF_Code(42), "arc_end")


	next := peek_group_code(parse_state)
	assert(next == DXF_Code(0))
}

parse_entity_insert :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	parse_header(parse_state, data)
	parse_code_assert_ignore(parse_state, DXF_Code(2), "component_name")
	parse_code_assert_ignore(parse_state, DXF_Code(10), "center_y")
	parse_code_assert_ignore(parse_state, DXF_Code(20), "center_y")
	parse_code_assert_ignore(parse_state, DXF_Code(30), "center_z")

	parse_code_optional_ignore(parse_state, DXF_Code(41), "scale_x")
	parse_code_optional_ignore(parse_state, DXF_Code(42), "scale_y")
	parse_code_optional_ignore(parse_state, DXF_Code(43), "scale_z")

	parse_code_optional_ignore(parse_state, DXF_Code(50), "rotation")
	parse_xdata(parse_state)

	next := peek_group_code(parse_state)
	assert(next == DXF_Code(0))
}

parse_entity_arc :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	parse_header(parse_state, data)
	parse_code_assert_ignore(parse_state, DXF_Code(10), "center_x")
	parse_code_assert_ignore(parse_state, DXF_Code(20), "center_y")
	parse_code_assert_ignore(parse_state, DXF_Code(30), "center_z")
	parse_code_assert_ignore(parse_state, DXF_Code(40), "radius")

	parse_code_optional_ignore(parse_state, DXF_Code(210), "extrusion_x")
	parse_code_optional_ignore(parse_state, DXF_Code(220), "extrusion_y")
	parse_code_optional_ignore(parse_state, DXF_Code(230), "extrusion_z")

	parse_code_assert_ignore(parse_state, DXF_Code(100), "subclass")
	parse_code_assert_ignore(parse_state, DXF_Code(50), "angle_start")
	parse_code_assert_ignore(parse_state, DXF_Code(51), "angle_end")

}


parse_code_assert_ignore :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code, _message: string) {
	code := parse_group_code(parse_state)
	parse_content_string(parse_state)
	assert(code == in_code)
}

parse_code_optional_ignore :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code, _message: string) {
	code := peek_group_code(parse_state)
	if code == in_code {
		parse_group_code(parse_state)
 		parse_content_string(parse_state)
	}
}

parse_header :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {

	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_ext := peek_group_code(parse_state)
	for maybe_ext == DXF_Code(102) {
		parse_extension(parse_state)
		maybe_ext = peek_group_code(parse_state)
	}

	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)

	parse_handle_common(parse_state, nil)


}

parse_entity_dimension :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	parse_header(parse_state, data)
	assert(parse_group_code(parse_state) == DXF_Code(2))
	dim_block := parse_content_string(parse_state)
	
	assert(parse_group_code(parse_state) == DXF_Code(10))
	def_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(20))
	def_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(30))
	def_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(11))
	text_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(21))
	text_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(31))
	text_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(70))
	dim_flags := parse_content_string(parse_state)

//////////////////////////////////////////////
	maybe_text_override := peek_group_code(parse_state)
	if maybe_text_override == DXF_Code(1) {
		parse_group_code(parse_state)
		override_text := parse_content_string(parse_state)
	}

	assert(parse_group_code(parse_state) == DXF_Code(71))
	text_attachment := parse_content_string(parse_state)

	//////
	maybe_measurement := peek_group_code(parse_state)
	if maybe_measurement == DXF_Code(42) {
		parse_group_code(parse_state)
		measurement := parse_content_string(parse_state)
	}
	////

	assert(parse_group_code(parse_state) == DXF_Code(3))
	dim_style := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(100))
	subclass_aligned_dim := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(13))
	line1_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(23))
	line1_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(33))
	line1_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(14))
	line2_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(24))
	line2_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(34))
	line2_z := parse_content_string(parse_state)

	maybe_rotation := peek_group_code(parse_state)
	if maybe_rotation == DXF_Code(50) {
		parse_group_code(parse_state)
		rotation := parse_content_string(parse_state)
	}

	if peek_group_code(parse_state) == DXF_Code(100) {
		assert(parse_group_code(parse_state) == DXF_Code(100))
		subclass_rotated_dimension := parse_content_string(parse_state)
	}

	parse_xdata(parse_state)
}


parse_entity_viewport :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_ext := peek_group_code(parse_state)
	if maybe_ext == DXF_Code(102) {
		parse_extension(parse_state)
	}

	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)

	parse_handle_common(parse_state, nil)
	// assert(parse_group_code(parse_state) == DXF_Code(6))
	// linetype := parse_content_string(parse_state)

	viewport := DXF_Viewport {}
	
	assert(parse_group_code(parse_state) == DXF_Code(10))
	viewport.center.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state))) 
	assert(parse_group_code(parse_state) == DXF_Code(20))
	viewport.center.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(30))
	viewport.center.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))

	assert(parse_group_code(parse_state) == DXF_Code(40))
	viewport.size.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(41))
	viewport.size.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
	
	
	assert(parse_group_code(parse_state) == DXF_Code(68))
	viewport_status := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(69))
	viewport_id := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(12))
	view_center_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(22))
	view_center_y := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(13))
	snap_base_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(23))
	snap_base_y := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(14))
	snap_spacing_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(24))
	snap_spacing_y := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(15))
	grid_spacing_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(25))
	grid_spacing_y := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(16))
	view_dir_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(26))
	view_dir_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(36))
	view_dir_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(17))
	cam_target_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(27))
	cam_target_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(37))
	cam_target_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(42))
	view_height := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(43))
	lens_length := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(44))
	front_clip := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(45))
	back_clip := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(50))
	twist := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(51))
	snap_rotation := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(72))
	circle_zoom := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(90))
	viewport_bits := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(1))
	frozen_layers := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(281))
	render_mode := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(71))
	ucsfollow := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(74))
	ucsicon := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(110))
	ucs_origin_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(120))
	ucs_origin_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(130))
	ucs_origin_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(111))
	ucs_right_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(121))
	ucs_right_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(131))
	ucs_right_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(112))
	ucs_up_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(122))
	ucs_up_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(132))
	ucs_up_z := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(79))
	ucs_ortho_type := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(146))
	ucs_elevation := parse_content_string(parse_state)

}

parse_entity_mtext :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)


	parse_handle_common(parse_state, nil)


	text := DXF_Text {}
	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(10):
				parse_group_code(parse_state)
				text.pos.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(20):
				parse_group_code(parse_state)
				text.pos.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(30):
				parse_group_code(parse_state)
				text.pos.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(40):
				parse_group_code(parse_state)
				text_height, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

			case DXF_Code(41):
				parse_group_code(parse_state)
				ref_rect_width := parse_content_string(parse_state)

			case DXF_Code(71):
				parse_group_code(parse_state)
				attachment_point := parse_content_string(parse_state) // index of [nw, n, ne, w, c, e, sw, s, se]
				
			case DXF_Code(72):
				parse_group_code(parse_state)
				flow_direction := parse_content_string(parse_state) // 1:LTR, 3:RTL, 5:ByStyle

			case DXF_Code(1):
				parse_group_code(parse_state)
				text.content = parse_content_string(parse_state)

			case DXF_Code(73):
				parse_group_code(parse_state)
				space_style := parse_content_string(parse_state) // 1:atleast 2:exact
			case DXF_Code(44):
				parse_group_code(parse_state)
				line_space_factor := parse_content_string(parse_state)
				/*
			case DXF_Code(50):
				parse_group_code(parse_state)
				angle := parse_content_string(parse_state)
			case DXF_Code(72):
				parse_group_code(parse_state)
				justification_horz := parse_content_string(parse_state)
*/
			case DXF_Code(11):
				parse_group_code(parse_state)
				end_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(21):
				parse_group_code(parse_state)
				end_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(31):
				parse_group_code(parse_state)
				end_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

			// case DXF_Code(100):
			// 	parse_group_code(parse_state)
			// 	subclass_text := parse_content_string(parse_state)

			case:
				done = true
		}
	}

	parse_xdata(parse_state)
	next := peek_group_code(parse_state)
	assert(next == DXF_Code(0))

	append(&data.texts, text)
}

parse_xdata :: proc(parse_state: ^DXF_ParseState) {
	maybe_xdata := peek_group_code(parse_state)
	if maybe_xdata == DXF_Code(0) {
		return
	}

	assert(parse_group_code(parse_state) == DXF_Code(1001))
	provider := parse_content_string(parse_state)

	for true {
		code := parse_group_code(parse_state)
		value := parse_content_string(parse_state)
		assert(int(code) >= 1000)

		next := peek_group_code(parse_state)
		if next < 1000 {
			break
		}
	}
	
}

parse_entity_text :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)


	parse_handle_common(parse_state, nil)


	text := DXF_Text {}
	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(10):
				parse_group_code(parse_state)
				text.pos.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(20):
				parse_group_code(parse_state)
				text.pos.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(30):
				parse_group_code(parse_state)
				text.pos.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(40):
				parse_group_code(parse_state)
				text_height, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

			case:
				done = true
		}
	}

	parse_code_optional_ignore(parse_state, DXF_Code(1), "text")
	parse_code_optional_ignore(parse_state, DXF_Code(100), "subclass text")

	append(&data.texts, text)
}

parse_extension :: proc(parse_state: ^DXF_ParseState) {
	assert(parse_group_code(parse_state) == 102)
	ext_name := parse_content_string(parse_state)
	assert(ext_name == "{ACAD_REACTORS" || ext_name == "{ACAD_XDICTIONARY")

	done := false
	for !done {
		switch parse_group_code(parse_state) {
			case DXF_Code(330):
				referenced := parse_content_string(parse_state)
			case DXF_Code(360):
				referenced := parse_content_string(parse_state)
			case DXF_Code(102):
				assert(parse_content_string(parse_state) == "}")
				done = true
		}
	}
	
}

parse_handle_common :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {

	unhandled := false
	for !unhandled {
		switch peek_group_code(parse_state) {
			case DXF_Code(100):
				parse_group_code(parse_state)
				subclass := parse_content_string(parse_state)
			case DXF_Code(8):
				parse_group_code(parse_state)
				layer_name := parse_content_string(parse_state)
			case DXF_Code(62): // color
				parse_group_code(parse_state)
				color := parse_content_string(parse_state)
			case DXF_Code(67): // space
				parse_group_code(parse_state)
				space := parse_content_string(parse_state) // 0: model space, 1: paper space
			case DXF_Code(6):
				parse_group_code(parse_state)
				linetype := parse_content_string(parse_state)
			case DXF_Code(48):
				parse_group_code(parse_state)
				linetype_scale := parse_content_string(parse_state)

			case DXF_Code(370): // weight
				parse_group_code(parse_state)
				line_weight := parse_content_string(parse_state)
				
			case:
				unhandled = true
		}
	}
}

parse_entity_line :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_reactor := peek_group_code(parse_state)
	if maybe_reactor == DXF_Code(102) {
		parse_extension(parse_state)
	}

	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)

	parse_handle_common(parse_state, nil)
	// assert(parse_group_code(parse_state) == DXF_Code(6))
	// linetype := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(10))
	start_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(20))
	start_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(30))
	start_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

	assert(parse_group_code(parse_state) == DXF_Code(11))
	end_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(21))
	end_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(31))
	end_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

	line := DXF_Line{
		start = {start_x, start_y, start_z},
		end = {end_x, end_y, end_z},
	}
	append(&data.lines, line)
}


parse_entity_circle :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)

	parse_handle_common(parse_state, nil)


	assert(parse_group_code(parse_state) == DXF_Code(10))
	center_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(20))
	center_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(30))
	center_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(40))
	radius, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

	circle := DXF_Circle {
		center = {center_x, center_y, center_z},
		radius = radius,
	}

	append(&data.circles, circle)
}

parse_entity_polyline :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_reactor := peek_group_code(parse_state)
	if maybe_reactor == DXF_Code(102) {
		parse_extension(parse_state)
	}


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)

	parse_handle_common(parse_state, nil)

	assert(parse_group_code(parse_state) == DXF_Code(90))
	vertex_count_str := parse_content_string(parse_state)
	vertex_count, _ := strconv.parse_uint(trim(vertex_count_str))

	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(70):
				parse_group_code(parse_state)
				polyline_flags := parse_content_string(parse_state)
			case DXF_Code(43):
				parse_group_code(parse_state)
				polyline_width := parse_content_string(parse_state)
			case DXF_Code(38):
				parse_group_code(parse_state)
				elevation := parse_content_string(parse_state)
			case:
				done = true
		}
	}

	polyline := DXF_Polyline {}
	polyline.points = make([]f64x2, vertex_count)
	polyline.bulges = make([]f64, vertex_count)
	

	idx := int(-1)
	done = false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(10):
				parse_group_code(parse_state)
				idx += 1
				value, ok := strconv.parse_f64(trim(parse_content_string(parse_state)))
				polyline.points[idx].x = value
			case DXF_Code(20):
				parse_group_code(parse_state)
				value, ok := strconv.parse_f64(trim(parse_content_string(parse_state)))
				polyline.points[idx].y = value
			case DXF_Code(42):
				parse_group_code(parse_state)
				value, ok := strconv.parse_f64(trim(parse_content_string(parse_state)))
				polyline.bulges[idx] = value
			case :
				done = true
		}
	}
	assert(idx == (int(vertex_count)-1))

	append(&data.polylines, polyline)

}


parse_entity_spline :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)


	parse_handle_common(parse_state, nil)


	assert(parse_group_code(parse_state) == DXF_Code(210))
	extrusion_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(220))
	extrusion_y := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(230))
	extrusion_z := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(70))
	spline_flags := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(71))
	spline_degree_str := parse_content_string(parse_state)
	spline_degree, _ := strconv.parse_uint(trim(spline_degree_str))


	assert(parse_group_code(parse_state) == DXF_Code(72))
	spline_numknots_str := parse_content_string(parse_state)
	spline_numknots, _ := strconv.parse_uint(trim(spline_numknots_str))

	assert(parse_group_code(parse_state) == DXF_Code(73))
	spline_numcontrolpts_ptr := parse_content_string(parse_state)
	spline_numcontrolpts, _ := strconv.parse_uint(trim(spline_numcontrolpts_ptr))

	//log.info("Parsing SPLINE", handle, " degree:", spline_degree, " knots:", spline_numknots, " ctrl_points:", spline_numcontrolpts)

	assert(parse_group_code(parse_state) == DXF_Code(74))
	spline_numfitpts := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(42))
	spline_tolerance_knot := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(43))
	spline_tolerance_controlpoints := parse_content_string(parse_state)

	spline := DXF_Spline {}
	spline.degree = spline_degree
	spline.knots = make([]f64, spline_numknots)
	spline.control_points = make([]f64x3, spline_numcontrolpts)

	for idx in 0..<spline_numknots {
		assert(parse_group_code(parse_state) == DXF_Code(40))
		knot_str := parse_content_string(parse_state)
		knot, ok := strconv.parse_f64(trim(knot_str))
		spline.knots[idx] = knot
	}

	for idx in 0..<spline_numcontrolpts {
		assert(parse_group_code(parse_state) == DXF_Code(10))
		control_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
		assert(parse_group_code(parse_state) == DXF_Code(20))
		control_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
		assert(parse_group_code(parse_state) == DXF_Code(30))
		control_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
		spline.control_points[idx] = {control_x, control_y, control_z}
	}	

	append(&data.splines, spline)

}


trim :: proc(value: string) -> string {
	trim_start := 0
	for value[trim_start] == ' ' {
		trim_start += 1
	}
	return value[trim_start:]
}




peek_group_code :: proc(cursor_ptr: ^DXF_ParseState) -> DXF_Code {
	cursor := cursor_ptr.cursor
	for cursor^ == ' ' || cursor^ == '\t' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	start := cursor
	for true {
		cursor = mem.ptr_offset(cursor, 1)
		if cursor^ < '0' || cursor^ > '9' {
			break;
		}
	}
	strlen := mem.ptr_sub(cursor, start) // exclude newline
	
	str := string(([^]byte)(start)[:strlen])
	result, ok := strconv.parse_uint(str)

	
	/*fmt.println("str: ", str)
	for char in str {
		fmt.print(char)
	}
	fmt.println()
	*/
	assert(ok)
	return DXF_Code(result)
}



parse_group_code :: proc(cursor_ptr: ^DXF_ParseState) -> DXF_Code {
	cursor := cursor_ptr.cursor
	for cursor^ == ' ' || cursor^ == '\t' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	start := cursor
	for true {
		cursor = mem.ptr_offset(cursor, 1)
		if cursor^ < '0' || cursor^ > '9' {
			break;
		}
	}
	strlen := mem.ptr_sub(cursor, start) // exclude newline

	for cursor^ != '\n' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	cursor = mem.ptr_offset(cursor, 1)
	
	cursor_ptr.cursor = cursor

	str := string(([^]byte)(start)[:strlen])
	str = trim(str)
	result, ok := strconv.parse_uint(str)
	// if (!ok) {
	// 	str2 := string(str)
	// 	fmt.printf("bad parse uint:'%s'\n", str2)
	// 	for char in str2 {
	// 		fmt.printf("%d", char)
	// 	}
	// 	fmt.printf("\nbad parse uint:'%s'\n", str)
	// }
	assert(ok)
	if PARSE_DEBUG { fmt.printf("%d:\t", result) }
	return DXF_Code(result)
}

parse_content_string :: proc(cursor_ptr: ^DXF_ParseState) -> string {
	cursor := cursor_ptr.cursor
	start := cursor
	for cursor^ != '\n' && cursor^ != '\r' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	strlen := mem.ptr_sub(cursor, start)
	for cursor^ == '\n' || cursor^ == '\r' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	cursor_ptr.cursor = cursor

	str := string(([^]byte)(start)[:strlen])
//	fmt.printf("found '%s'\n", str)
	if PARSE_DEBUG { fmt.printf("%s\n", str) }
	return str
}

