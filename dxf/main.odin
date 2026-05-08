
package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:strconv"
import "core:mem"

import "engine:ui"
import ab "engine:."

import SDL "vendor:sdl3"

main :: proc() {
	fmt.println("hello world")
	ab.app_init(nil, init, iterate)
}


dxf: DXF_Data

init :: proc() {
	log.info("init")

	num_drivers := SDL.GetNumRenderDrivers()

	for idx in 0..<num_drivers {
		driver := SDL.GetRenderDriver(idx)
		log.info("found driver:", driver)
	}

	ui.create_window("Editor", {1280, 720})

	file_size: uint
	file := ([^]byte)( SDL.LoadFile("content/trex.dxf", &file_size) )
	as_string := cstring(file)
//	log.info("file:\n", as_string)
	bytes := file[:file_size]
	dxf = parse_dxf(bytes)
}


iterate :: proc() {


	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
	SDL.RenderClear(ab.renderer)

	SDL.SetRenderDrawColorFloat(ab.renderer, 1, 0, 0, 1)


	ab.draw_set_view_basis({50, 0}, {0, -50}, {0,0})
	for spline in dxf.splines {
		control_points := spline.control_points
		for idx in 1..<len(control_points) {
			prev := control_points[idx-1]
			next := control_points[idx]
			ab.draw_line(
				ab.renderer,
				{f32(prev.x), f32(prev.y)},
				{f32(next.x), f32(next.y)},
				1.0,
			)
		}
	}

	ab.draw_present()

	err := SDL.GetError()
	if (err != nil && len(err) != 0) {
		fmt.println(err)

	}
}



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
		}
		fmt.println(group_code, ":", content)
	}

	log.info("Finished parsing ENTITIES")
}

parse_entity_spline :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	log.info("Parsing SPLINE", handle)

	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)



	assert(parse_group_code(parse_state) == DXF_Code(100))
	subclass_entity := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(8))
	layer_name := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(370))
	line_weight := parse_content_string(parse_state)



	assert(parse_group_code(parse_state) == DXF_Code(100))
	subclass_spline := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(210))
	extrusion_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(220))
	extrusion_y := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(230))
	extrusion_z := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(70))
	spline_flags := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(71))
	spline_degree := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(72))
	spline_numknots_str := parse_content_string(parse_state)
	spline_numknots, _ := strconv.parse_uint(trim(spline_numknots_str))

	assert(parse_group_code(parse_state) == DXF_Code(73))
	spline_numcontrolpts_ptr := parse_content_string(parse_state)
	spline_numcontrolpts, _ := strconv.parse_uint(trim(spline_numcontrolpts_ptr))

	assert(parse_group_code(parse_state) == DXF_Code(74))
	spline_numfitpts := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(42))
	spline_tolerance_knot := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(43))
	spline_tolerance_controlpoints := parse_content_string(parse_state)

	spline := DXF_Spline {}
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


DXF_Code :: distinct u32

DXF_SECTION :: "SECTION"
DXF_SPLINE :: "SPLINE"
DXF_EOF :: "EOF"
DXF_ENDSEC :: "ENDSEC"
DXF_ENTITIES :: "ENTITIES"

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
	splines: [dynamic]DXF_Spline,
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

f64x3 :: [3]f64

DXF_Spline :: struct {
	flags: uint,
	degree: uint,
	knots: []f64,
	control_points: []f64x3,
}


trim :: proc(value: string) -> string {
	trim_start := 0
	for value[trim_start] == ' ' {
		trim_start += 1
	}
	return value[trim_start:]
}




peek_group_code :: proc(cursor_ptr: ^byte) -> uint {
	cursor := cursor_ptr
	for cursor^ == ' ' {
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
	assert(ok)
	return result	
}


parse_group_code :: proc(cursor_ptr: ^DXF_ParseState) -> DXF_Code {
	cursor := cursor_ptr.cursor
	for cursor^ == ' ' {
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
	result, ok := strconv.parse_uint(str)
	assert(ok)
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
	return str
}

