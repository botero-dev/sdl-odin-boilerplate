
package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:strconv"
import "core:strings"

import ab "engine:."
import "engine:gfx"
import "engine:ui"

import SDL "vendor:sdl3"

import "dxf"

f32x2 :: [2]f32
f32x3 :: [3]f32

f64x2 :: [2]f64
f64x3 :: [3]f64

vconv_f64x2_f32x2 :: proc (input: f64x2) -> f32x2 { return f32x2{ f32(input.x), f32(input.y) } }

vconv :: proc {
	vconv_f64x2_f32x2
}


main :: proc() {
	fmt.println("hello world")
	ab.app_init(nil, init, iterate)
}


init :: proc() {
	log.info("init")

	num_drivers := SDL.GetNumRenderDrivers()

	for idx in 0 ..< num_drivers {
		driver := SDL.GetRenderDriver(idx)
		log.info("found driver:", driver)
	}

	ui.create_window("Editor", {1280, 720})
	ab.app_add_event_handler(my_handler)

	ab.request_data_async("casa1.dxf", nil, dxf_callback)

	ab.request_data_async("Play-Regular.ttf", nil, assign_font)
}


assign_font :: proc(result: ab.RequestResult) {

	bytes := result.bytes
	assert(len(bytes) != 0)
	io := SDL.IOFromConstMem(&bytes[0], len(bytes))

	font_id = ab.load_font_io(io)
}

model: Model
model_loaded: bool = false

dxf_callback :: proc(result: ab.RequestResult) {

	model = model_from_dxf(result.bytes)


	scale_x := f64(ab.win_size.x) / model.size.x
	scale_y := f64(ab.win_size.y) / model.size.y

	scale := math.min(scale_x, scale_y) * 1.1

	viewport.basis_x = {scale, 0}
	viewport.basis_y = {0, -scale}
	viewport.origin = model.center


	model_loaded = true
}


viewport := ViewportState{
	basis_x = {1, 0},
	basis_y = {0, -1},
	origin = {0,0},
}


mouse_pressed := false
grab_coords := [2]f64{0, 0}

my_handler :: proc(event: ^ab.Event) {
	vp_size := f64x2 { f64(ab.win_size.x), f64(ab.win_size.y)}
	if event.sdl_event.type == .MOUSE_WHEEL {
		wheel_evt := (^SDL.MouseWheelEvent)(event.sdl_event)

		scale := math.pow(1.1, f64(wheel_evt.y))
		viewport.basis_x *= scale
		viewport.basis_y *= scale

		mouse_coords := linalg.round([2]f32{wheel_evt.mouse_x, wheel_evt.mouse_y})
		mouse_model_pos := view_to_model(viewport, vp_size, mouse_coords)

		viewport.origin += (viewport.origin - mouse_model_pos) * (1-scale)

	}



	if event.sdl_event.type == .MOUSE_BUTTON_DOWN {
		mouse_pressed = true
		mouse_btn_evt := (^SDL.MouseButtonEvent)(event.sdl_event)
		mouse_coords := linalg.round([2]f32{mouse_btn_evt.x, mouse_btn_evt.y})

		model_coords := view_to_model(viewport, vp_size, mouse_coords)
		grab_coords = model_coords
	}
	if event.sdl_event.type == .MOUSE_BUTTON_UP {
		mouse_pressed = false
	}
	if event.sdl_event.type == .MOUSE_MOTION {
		mouse_motion := (^SDL.MouseMotionEvent)(event.sdl_event)
		mouse_coords := linalg.round([2]f32{mouse_motion.x, mouse_motion.y})
		model_coords := view_to_model(viewport, vp_size, mouse_coords)

		if mouse_pressed {
			delta := model_coords - grab_coords
			viewport.origin -= delta
		}
	}
}


iterate :: proc() {

	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
	SDL.RenderClear(ab.renderer)

	if model_loaded {
		viewport.data = &model
		vp_draw(viewport)
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
