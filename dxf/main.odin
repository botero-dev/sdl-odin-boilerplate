
package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:strconv"
import "core:mem"
import "core:math"
import "core:math/linalg"

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
	file := ([^]byte)( SDL.LoadFile("content/casa1.dxf", &file_size) )
	// file := ([^]byte)( SDL.LoadFile("content/trex.dxf", &file_size) )
	as_string := cstring(file)
//	log.info("file:\n", as_string)
	bytes := file[:file_size]
	dxf = parse_dxf(bytes)

	convert_curves()
	ab.app_add_event_handler(my_handler)
}

my_handler :: proc(event: ^ab.Event) {
	if event.sdl_event.type == .MOUSE_WHEEL{
		wheel_evt := (^SDL.MouseWheelEvent)(event.sdl_event)

		scale *= math.pow(1.02, wheel_evt.y)
		log.info("scale:", scale)
	}
}




CurveBezierCubic :: struct {
	points: []f64x3
}

curves: [dynamic]CurveBezierCubic

convert_curves :: proc() {
	for spline in dxf.splines {
		if len(spline.knots) == (len(spline.control_points) + int(spline.degree) + 1) {
			segments := (len(spline.control_points) - 1) / int(spline.degree)
			// can be simplified to bezier curve
			last_knot := spline.knots[0]
			multiplicity := 1
			segment := 0

			meets_criteria := true

			for idx in 1..<len(spline.knots) {
				if spline.knots[idx] == last_knot {
					multiplicity += 1
				} else { // new knot, check previous knot validity
					if multiplicity == 3 {
						//meets_criteria = true
					} else if segment == 0 && multiplicity == 4 {
						// meets_criteria = true
					} else {
						meets_criteria = false
						break;
					}
					if !meets_criteria {
						break
					}
					multiplicity = 1
					last_knot = spline.knots[idx]
				}
			}

			if multiplicity != 4 {
				meets_criteria = false
			}

			if !meets_criteria {
				continue
			}

			bezier := CurveBezierCubic {
				points = spline.control_points
			}

			append(&curves, bezier)

		}

	}
}

scale := f32(50)
origin := [2]f32 {5000, 0}

iterate :: proc() {


	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
	SDL.RenderClear(ab.renderer)

	SDL.SetRenderDrawColorFloat(ab.renderer, 1, 0, 0, 1)


	ab.draw_set_view_basis({scale, 0}, {0, -scale}, origin)
	/*
	for spline in dxf.splines {
		draw_spline(spline)
	}
		*/

	for line in lines {
		ab.draw_line(
			ab.renderer,
			{f32(line.start.x), f32(line.start.y)},
			{f32(line.end.x), f32(line.end.y)},
			1.0,
		)
	}

	for polyline in dxf.polylines {
		prev := polyline.points[0]
		for idx in 1..<len(polyline.points) {
			next := polyline.points[idx]
			ab.draw_line(
				ab.renderer,
				{f32(prev.x), f32(prev.y)},
				{f32(next.x), f32(next.y)},
				1.0,
			)	
			prev = next
		}
		
	}
	
	for curve in curves {
		num_segments := (len(curve.points) - 1) / 3
		for idx  in 0..<num_segments {
			a := curve.points[idx * 3 + 0]
			b := curve.points[idx * 3 + 1]
			c := curve.points[idx * 3 + 2]
			d := curve.points[idx * 3 + 3]

			prev := a
			SUBDIVS :: 20
			for s in 1..=SUBDIVS {
				t := f64(s) / SUBDIVS
				lab := lerp(a, b, t)
				lbc := lerp(b, c, t)
				lcd := lerp(c, d, t)
				labc := lerp(lab, lbc, t)
				lbcd := lerp(lbc, lcd, t)
				next := lerp(labc, lbcd, t)
				
			ab.draw_line(
				ab.renderer,
				{f32(prev.x), f32(prev.y)},
				{f32(next.x), f32(next.y)},
				1.0,
			)
				prev = next

			}
		}
	}

	ab.draw_present()

	err := SDL.GetError()
	if (err != nil && len(err) != 0) {
		fmt.println(err)

	}
}

draw_spline_old :: proc(spline: DXF_Spline) {
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

V2 :: [3]f64

lerp :: proc(a, b: V2, t: f64) -> V2 {
	t1 := f64(t)
	return a * (1.0 -t1) + b * t1
}

spline3 :: proc(
    cp: []V2,
    knots: []f64,
    t: f64,
) -> V2 {

    s := 3

    for s < len(knots)-4 && t >= knots[s+1] {
        s += 1
    }

    d: [4]V2

    for i in 0..<4 {
        d[i] = cp[(s-3+i) % len(cp)]
    }

    for r in 1..=3 {
        for j := 3; j >= r; j -= 1 {

            i := s - 3 + j

            den := knots[i + 4 - r] - knots[i]

            a: f64 = 0

            if den != 0 {
                a = (t - knots[i]) / den
            }

            d[j] = lerp(d[j-1], d[j], a)
        }
    }

    return d[3]
}

draw_spline :: proc(spline: DXF_Spline) {
	cp := spline.control_points
	knots := spline.knots
    t0 := knots[3]
    t1 := knots[len(knots)-4]

    prev := spline3(cp, knots, t0)

    STEPS :: 128

    for i in 1..=STEPS {

        t := t0 + (t1 - t0) * f64(i) / f64(STEPS)

        p := spline3(cp, knots, t)

        //draw_line(prev.x, prev.y, p.x, p.y)
			ab.draw_line(
				ab.renderer,
				{f32(prev.x), f32(prev.y)},
				{f32(p.x), f32(p.y)},
				1.0,
			)


        prev = p
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
		}
		fmt.println(group_code, ":", content)
	}

	log.info("Finished parsing ENTITIES")
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

			case DXF_Code(1):
				parse_group_code(parse_state)
				text.content = parse_content_string(parse_state)

			case DXF_Code(50):
				parse_group_code(parse_state)
				angle := parse_content_string(parse_state)
			case DXF_Code(72):
				parse_group_code(parse_state)
				justification_horz := parse_content_string(parse_state)

			case DXF_Code(11):
				parse_group_code(parse_state)
				end_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(21):
				parse_group_code(parse_state)
				end_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(31):
				parse_group_code(parse_state)
				end_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

			case DXF_Code(100):
				parse_group_code(parse_state)
				subclass_text := parse_content_string(parse_state)

			case DXF_Code(73):
				parse_group_code(parse_state)
				justification_vert := parse_content_string(parse_state)
			case:
				done = true
		}
	}

	append(&texts, text)
}

DXF_Text :: struct {
	content: string,
	pos: f64x3,
	end: f64x3,
}

texts: [dynamic]DXF_Text

parse_reactor :: proc(parse_state: ^DXF_ParseState) {
	assert(parse_group_code(parse_state) == 102)
	assert(parse_content_string(parse_state) == "{ACAD_REACTORS")

	done := false
	for !done {
		switch parse_group_code(parse_state) {
			case DXF_Code(330):
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
		parse_reactor(parse_state)
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
	append(&lines, line)
}

DXF_Line :: struct {
	start: f64x3,
	end: f64x3,
}

lines: [dynamic]DXF_Line

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

	append(&circles, circle)
}

DXF_Circle :: struct {
	center: f64x3,
	radius: f64,
}

circles: [dynamic]DXF_Circle

parse_entity_polyline :: proc(parse_state: ^DXF_ParseState, data: ^DXF_Data) {
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_reactor := peek_group_code(parse_state)
	if maybe_reactor == DXF_Code(102) {
		parse_reactor(parse_state)
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

	log.info("Parsing SPLINE", handle, " degree:", spline_degree, " knots:", spline_numknots, " ctrl_points:", spline_numcontrolpts)

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



DXF_Code :: distinct u32

DXF_CIRCLE :: "CIRCLE"
DXF_ENDSEC :: "ENDSEC"
DXF_ENTITIES :: "ENTITIES"
DXF_EOF :: "EOF"
DXF_LINE :: "LINE"
DXF_LWPOLYLINE :: "LWPOLYLINE"
DXF_SECTION :: "SECTION"
DXF_SPLINE :: "SPLINE"
DXF_TEXT :: "TEXT"

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


PARSE_DEBUG :: false

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

