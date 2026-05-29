
package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:strconv"
import "core:strings"

import ab "engine:."
import "engine:gfx"
import "engine:ui"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import "dxf"


f64x2 :: dxf.f64x2
f64x3 :: dxf.f64x3

main :: proc() {
	fmt.println("hello world")
	ab.app_init(nil, init, iterate)
}


dxf_file: dxf.DXF_Data
dxf_loaded := false

init :: proc() {
	log.info("init")

	num_drivers := SDL.GetNumRenderDrivers()

	for idx in 0 ..< num_drivers {
		driver := SDL.GetRenderDriver(idx)
		log.info("found driver:", driver)
	}

	ui.create_window("Editor", {1280, 720})

	ab.request_data_async("casa1.dxf", nil, dxf_callback)

	ab.request_data_async("Play-Regular.ttf", nil, assign_font)
}


assign_font :: proc(result: ab.RequestResult) {

	bytes := result.bytes
	assert(len(bytes) != 0)
	io := SDL.IOFromConstMem(&bytes[0], len(bytes))

	font_id = ab.load_font_io(io)
}


dxf_callback :: proc(result: ab.RequestResult) {
	dxf_file = dxf.parse_dxf(result.bytes)

	post_import()
	dxf_loaded = true
	ab.app_add_event_handler(my_handler)
}


CurveBezierCubic :: struct {
	points: []f64x3,
}

curves_list: [dynamic]CurveBezierCubic

post_import :: proc() {

	convert_curves(dxf_file, &curves_list)

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

	for curve in curves_list {
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
origin := [2]f32{870, -80}


mouse_pressed := false
grab_coords := [2]f32{0, 0}

my_handler :: proc(event: ^ab.Event) {
	if event.sdl_event.type == .MOUSE_WHEEL {
		wheel_evt := (^SDL.MouseWheelEvent)(event.sdl_event)

		scale *= math.pow(1.05, wheel_evt.y)
	}

	if event.sdl_event.type == .MOUSE_BUTTON_DOWN {
		mouse_pressed = true
		mouse_btn_evt := (^SDL.MouseButtonEvent)(event.sdl_event)
		mouse_coords := linalg.round([2]f32{mouse_btn_evt.x, mouse_btn_evt.y})

		model_coords := view_to_model(mouse_coords)
		grab_coords = model_coords
	}
	if event.sdl_event.type == .MOUSE_BUTTON_UP {
		mouse_pressed = false
	}
	if event.sdl_event.type == .MOUSE_MOTION {
		mouse_motion := (^SDL.MouseMotionEvent)(event.sdl_event)
		mouse_coords := linalg.round([2]f32{mouse_motion.x, mouse_motion.y})
		model_coords := view_to_model(mouse_coords)

		if mouse_pressed {
			delta := model_coords - grab_coords
			origin -= delta
		}
	}
}

view_to_model :: proc(in_coords: [2]f32) -> [2]f32 {

	right := [2]f32{scale, 0}
	up := [2]f32{0, -scale}
	draw_size := ab.win_size

	draw_matrix: matrix[3, 3]f32 = 1
	offset := origin
	draw_matrix = draw_matrix * matrix[3, 3]f32{
				1, 0, -offset.x,
				0, 1, -offset.y,
				0, 0, 1,
			}

	scale_mat := matrix[3, 3]f32{
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
	}

	scale_mat[0] = {right.x, right.y, 0}
	scale_mat[1] = {up.x, up.y, 0}

	draw_matrix = scale_mat * draw_matrix

	midpoint := draw_size / 2

	center := [2]f32{f32(midpoint.x), f32(midpoint.y)}

	draw_matrix = matrix[3, 3]f32{
			1, 0, center.x,
			0, 1, center.y,
			0, 0, 1,
		} * draw_matrix

	model_to_view := draw_matrix
	view_to_model_mat := linalg.inverse(model_to_view)

	result := view_to_model_mat * [3]f32{in_coords.x, in_coords.y, 1}

	return {result.x, result.y}
}

Color :: [4]f32

colors := []Color {
	{1, 0, 1, 1}, // color is ByBlock, we shouldn't use this
	{1, 0, 0, 1}, // 1
	{1, 1, 0, 1}, // 2
	{0, 1, 0, 1}, // 3
	{0, 1, 1, 1}, // 4
	{0, 0, 1, 1}, // 5
	{1, 0, 1, 1}, // 6
	{1, 1, 1, 1}, // 7
}


entity_style :: proc(entity: dxf.DXF_Entity, file: dxf.DXF_Data) -> gfx.LineStyleSimple {
	color := [4]f32{1, 1, 1, 1}

	index := entity.color

	if index == 0 {
		// TODO: resolve block color, which could be bylayer
		index = rand.int_range(1, 3)
	}

	if entity.color == 256 {
		// TODO: grab from layer
		layer := file.layers[entity.layer]
		index = layer.color
	}
	if index == 0 {
		color = colors[rand.int_range(1, 7)]
	} else if index < len(colors) {
		color = colors[index]
	} else {
		color = colors[7]
	}

	return gfx.LineStyleSimple{width = 1, color = color}
}


font_id := ab.NIL_FONT
font_steps := []u16 {
	8,
	10,
	12,
	14,
	16,
	20,
	24,
	38,
	32,
	36,
	40,
	48,
	56,
	64,
	72,
	96,
}

iterate :: proc() {


	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
	SDL.RenderClear(ab.renderer)

	SDL.SetRenderDrawColorFloat(ab.renderer, 1, 0, 0, 1)

	ab.draw_set_view_basis({scale, 0}, {0, -scale}, origin)

	if (dxf_loaded) {

		draw_text :: proc(text: dxf.Entity_Text) {
			in_pos := text.pos
			content := text.content
			entity := text.entity
			pos := [3]f32{f32(in_pos.x), f32(in_pos.y), 1}
			new_pos := ab.draw_matrix * pos

			cstr := strings.clone_to_cstring(content, context.temp_allocator)

			color := entity_style(entity, dxf_file).color

			in_fwd := [3]f32{ f32(text.end.x), f32(text.end.y), f32(text.end.z)}
			fwd := pos + (in_fwd * f32(text.height))
			pos_fwd := ab.draw_matrix * fwd

			dir_fwd := pos_fwd - new_pos
			
			screen_size := linalg.length(dir_fwd)

			font_size := u16(0)
			for step in font_steps {
				if f32(step) >= screen_size {
					font_size = step
					break
				}
				font_size = step
			}

			sdl_text := ab.get_text_with_font_size(font_id, font_size)

			dir_fwd /= f32(font_size)
			dir_up := linalg.cross(dir_fwd, [3]f32{0, 0, -1})

			if sdl_text != nil {
				
				tx : matrix[3,3]f32 = 1

				tx[0] = { f32(dir_fwd.x), f32(dir_fwd.y), 0}
				tx[1] = { f32(dir_up.x), f32(dir_up.y), 0}

				tx[2] = { f32(new_pos.x), f32(new_pos.y), 1}

				tx = linalg.transpose(tx)

			

				TTF.SetTextColor(
					sdl_text,
					u8(color[0] * 255),
					u8(color[1] * 255),
					u8(color[2] * 255),
					u8(color[3] * 255),
				)
				TTF.SetTextString(sdl_text, cstr, uint(len(content)))
				TTF.SetTextWrapWidth(sdl_text, 0)
				// math.round(new_pos.x), math.round(new_pos.y)
				TTF.DrawRendererTextTx(sdl_text, 0, 0, &tx[0][0])
			}
		}
		free_all(context.temp_allocator)

		for text in dxf_file.texts {
			draw_text(text)
		}

		for text in dxf_file.mtexts {
			draw_text(text)
		}


		for circle in dxf_file.circles {
			gfx.draw_circle(
				{{f32(circle.center.x), f32(circle.center.y)}, f32(circle.radius)},
				{line = entity_style(circle, dxf_file)},
			)
		}

		for line in dxf_file.lines {
			style := entity_style(line, dxf_file)
			ab.draw_line(
				ab.renderer,
				{f32(line.start.x), f32(line.start.y)},
				{f32(line.end.x), f32(line.end.y)},
				1.0,
				style.color,
			)

		}

		for polyline in dxf_file.polylines {
			style := entity_style(polyline, dxf_file)
			prev := polyline.points[0]
			for idx in 1 ..< len(polyline.points) {
				next := polyline.points[idx]
				ab.draw_line(
					ab.renderer,
					{f32(prev.x), f32(prev.y)},
					{f32(next.x), f32(next.y)},
					1.0,
					style.color,
				)
				prev = next
			}

		}

		for curve in curves_list {
			num_segments := (len(curve.points) - 1) / 3
			for idx in 0 ..< num_segments {
				a := curve.points[idx * 3 + 0]
				b := curve.points[idx * 3 + 1]
				c := curve.points[idx * 3 + 2]
				d := curve.points[idx * 3 + 3]

				prev := a
				SUBDIVS :: 20
				for s in 1 ..= SUBDIVS {
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
	}

	ab.draw_present()

	err := SDL.GetError()
	if (err != nil && len(err) != 0) {
		fmt.println(err)

	}
}

lerp :: proc(a, b: f64x3, t: f64) -> f64x3 {
	t1 := f64(t)
	return a * (1.0 - t1) + b * t1
}
