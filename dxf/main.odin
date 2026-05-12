
package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:strconv"
import "core:mem"
import "core:math"
import "core:math/linalg"

import "engine:ui"
import "engine:gfx"
import ab "engine:."

import SDL "vendor:sdl3"

import "dxf"


f64x2 :: dxf.f64x2
f64x3 :: dxf.f64x3

main :: proc() {
	fmt.println("hello world")
	ab.app_init(nil, init, iterate)
}


dxf_file: dxf.DXF_Data

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
	//file := ([^]byte)( SDL.LoadFile("content/casa0.dxf", &file_size) )
	//file := ([^]byte)( SDL.LoadFile("content/trex.dxf", &file_size) )
	as_string := cstring(file)
//	log.info("file:\n", as_string)
	bytes := file[:file_size]
	dxf_file = dxf.parse_dxf(bytes)

	convert_curves()
	ab.app_add_event_handler(my_handler)
}



CurveBezierCubic :: struct {
	points: []f64x3
}

curves: [dynamic]CurveBezierCubic

convert_curves :: proc() {
	for spline in dxf_file.splines {
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


	minx := f64(0)
	miny := f64(0)
	maxx := f64(0)
	maxy := f64(0)
	started := false
	
	for line in dxf_file.lines {
		if !started {
			minx = line.start.x
			miny = line.start.y
			maxx = line.start.x
			maxy = line.start.y
			started = true
		}

		minx = math.min(minx, line.start.x, line.end.x)
		miny = math.min(miny, line.start.y, line.end.y)
		maxx = math.max(maxx, line.start.x, line.end.x)
		maxy = math.max(maxy, line.start.y, line.end.y)
	}

	for polyline in dxf_file.polylines {
		if !started {
			minx = polyline.points[0].x
			miny = polyline.points[0].y
			maxx = polyline.points[0].x
			maxy = polyline.points[0].y
			started = true
		}

		for point in polyline.points {
			minx = math.min(minx, point.x)
			miny = math.min(miny, point.y)
			maxx = math.max(maxx, point.x)
			maxy = math.max(maxy, point.y)
		}
	}

	for curve in curves {
		if !started {
			minx = curve.points[0].x
			miny = curve.points[0].y
			maxx = curve.points[0].x
			maxy = curve.points[0].y
			started = true
		}

		for point in curve.points {
			minx = math.min(minx, point.x)
			miny = math.min(miny, point.y)
			maxx = math.max(maxx, point.x)
			maxy = math.max(maxy, point.y)
		}
	}

	

	size_x := maxx - minx
	size_y := maxy - miny

	center_x := size_x * 0.5 + minx
	center_y := size_y * 0.5 + miny

	origin = {f32(center_x), f32(center_y)}

	scale_x := f64(ab.win_size.x) / size_x
	scale_y := f64(ab.win_size.y) / size_y

	scale = f32(math.min(scale_x, scale_y) * 1.1)

}

scale := f32(1)
origin := [2]f32 {870, -80}


mouse_pressed := false
grab_coords := [2]f32 {0, 0}

my_handler :: proc(event: ^ab.Event) {
	if event.sdl_event.type == .MOUSE_WHEEL{
		wheel_evt := (^SDL.MouseWheelEvent)(event.sdl_event)

		scale *= math.pow(1.05, wheel_evt.y)
	}

	if event.sdl_event.type == .MOUSE_BUTTON_DOWN {
		mouse_pressed = true
		mouse_btn_evt := (^SDL.MouseButtonEvent)(event.sdl_event) 
		mouse_coords := [2]f32{mouse_btn_evt.x, mouse_btn_evt.y}

		model_coords := view_to_model(mouse_coords)
		grab_coords = model_coords
	}
	if event.sdl_event.type == .MOUSE_BUTTON_UP {
		mouse_pressed = false
	}
	if event.sdl_event.type == .MOUSE_MOTION {
		mouse_motion := (^SDL.MouseMotionEvent)(event.sdl_event) 
		mouse_coords := [2]f32{mouse_motion.x, mouse_motion.y}
		model_coords := view_to_model(mouse_coords)

		if mouse_pressed {
			delta := model_coords - grab_coords
			origin -= delta
		}
	}
}


view_to_model :: proc (in_coords: [2]f32) -> [2]f32 {

	right := [2]f32{scale, 0}
	up := [2]f32{0, -scale}
	draw_size := ab.win_size

	draw_matrix: matrix[3, 3]f32 = 1
	offset := origin
	draw_matrix = draw_matrix * matrix[3,3]f32 {
		1, 0, -offset.x,
		0, 1, -offset.y,
		0, 0, 1,
	}

	scale_mat := matrix[3,3]f32 {
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
	}

	scale_mat[0] = {right.x, right.y, 0}
	scale_mat[1] = {up.x, up.y, 0}

	draw_matrix = scale_mat * draw_matrix

	midpoint := draw_size / 2

	center := [2]f32{f32(midpoint.x), f32(midpoint.y)}

	draw_matrix =  matrix[3,3]f32 {
		1, 0, center.x,
		0, 1, center.y,
		0, 0, 1,
	} * draw_matrix

	model_to_view := draw_matrix
	view_to_model_mat := linalg.inverse(model_to_view)

	result := view_to_model_mat * [3]f32{in_coords.x, in_coords.y, 1}
	
	return {result.x, result.y}
}


iterate :: proc() {


	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
	SDL.RenderClear(ab.renderer)

	SDL.SetRenderDrawColorFloat(ab.renderer, 1, 0, 0, 1)


	ab.draw_set_view_basis({scale, 0}, {0, -scale}, origin)

	for circle in dxf_file.circles {
		gfx.draw_circle(
			{ {f32(circle.center.x), f32(circle.center.y)}, f32(circle.radius) },
			{
				line = gfx.LineStyleSimple {width = 1},
			}
		)
	}

	
	for line in dxf_file.lines {
		ab.draw_line(
			ab.renderer,
			{f32(line.start.x), f32(line.start.y)},
			{f32(line.end.x), f32(line.end.y)},
			1.0,
		)

	}

	for polyline in dxf_file.polylines {
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


lerp :: proc(a, b: f64x3, t: f64) -> f64x3 {
	t1 := f64(t)
	return a * (1.0 -t1) + b * t1
}
