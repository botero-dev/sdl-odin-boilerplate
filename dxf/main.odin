
package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:strconv"
import "core:strings"

import "base:runtime"

import ab "engine:."
import "engine:gfx"
import "engine:ui"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"
import clay "engine:clay-odin"

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

	ab.create_window("Editor", {1280, 720})
	//ab.app_add_event_handler(my_handler)

	// TODO: check if called with startup args to avoid loading `casa`1
	//ab.request_data_async("mailbox.dxf", nil, dxf_callback)
	//ab.request_data_async("bogota.dxf", nil, dxf_callback)
	//ab.request_data_async("casa0.dxf", nil, dxf_callback)
	ab.request_data_async("casa1.dxf", nil, dxf_callback)
	//ab.request_data_async("trex.dxf", nil, dxf_callback)

	ab.request_data_async("NotoSansCJK-VF.otf.ttc", nil, assign_font)
	//ab.request_data_async("Play-Regular.ttf", nil, assign_font)


	id_menus := ui.panels_register_definition({    callback=panel_menus,     name="menus"})
	id_toolbox := ui.panels_register_definition({  callback=panel_toolbox,   name="toolbox"})
	id_viewport := ui.panels_register_definition({ callback=layout_viewport, name="viewport", grow=true})
	id_layers := ui.panels_register_definition({   callback=layout_layers,   name="layers",   show_tab=true})
	id_statusbar := ui.panels_register_definition({   callback=layout_statusbar,   name="statusbar",   show_tab=false})

	main_vertical := ui.PanelLayoutGroup { direction = .Vertical }

	append(&main_vertical.items, ui.PanelLayoutRegisteredItem {id_menus})
	append(&main_vertical.items, ui.PanelLayoutRegisteredItem {id_toolbox})

	main_content := ui.PanelLayoutGroup { direction = .Horizontal, grow = true}
	append(&main_content.items, ui.PanelLayoutRegisteredItem {id_viewport})
	append(&main_content.items, ui.PanelLayoutRegisteredItem {id_layers})

	append(&main_vertical.items, main_content)

	append(&main_vertical.items, ui.PanelLayoutRegisteredItem {id_statusbar})

	panels.root = main_vertical

	//r := SDL.SetWindowRelativeMouseMode(ab.window, true)

	//log.info("set relative mous mode:", r)\
}

panels := ui.PanelLayout {}

panel_menus :: proc() {

	ui.layout_container(ui.Layout_Linear_Horizontal {})

	ui.layout_button("File")
	ui.layout_button("Edit")
	ui.layout_button("Stuff")

	ui.layout_close()
}

panel_toolbox :: proc() {
	
	ui.layout_container(ui.Layout_Linear_Vertical{})
	// tabs
	ui.layout_container(ui.Layout_Linear_Horizontal{})
	ui.layout_button("Draw")
	ui.layout_button("Measure")
	ui.layout_button("Review")
	ui.layout_close()
	

	ui.layout_container(ui.Layout_Linear_Horizontal{})
	ui.layout_button("Line")
	ui.layout_button("Circle")
	ui.layout_button("Spline")
	ui.layout_close()
	
	ui.layout_close()
}




assign_font :: proc(result: ab.RequestResult) {

	bytes := result.bytes
	assert(len(bytes) != 0)
	io := SDL.IOFromConstMem(&bytes[0], len(bytes))

	font_id = ui.load_font_io(io)
}

model: Model
model_loaded: bool = false

dxf_callback :: proc(result: ab.RequestResult) {
	if model_loaded {
		return
	}
	load_dxf_bytes_2(&result.bytes[0], len(result.bytes))
}

@(export)
js_alloc :: proc "c" (size: int) -> ^byte {
	//ptr := make([]byte, size)
	//return &ptr[0]
	return &my_buffer[0]
}

MY_BUFFER_SIZE :: 64 * 1024 * 1024
my_buffer: [MY_BUFFER_SIZE]byte

@(export)
load_dxf_bytes :: proc "c" (ptr: [^]byte, size: int) {
	context = ab.ctx
	load_dxf_bytes_2(ptr, size)
}

load_dxf_bytes_2 :: proc (ptr: [^]byte, size: int) {
	bufff := string(ptr[:size])

	model = model_from_dxf(ptr[:size])

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

mouse_coords := [2]f32{0, 0}
current_scale: f32

SCALE_POWER :: 2

my_handler :: proc(event: ^ab.Event, user_data: rawptr) {
	vp_size := f64x2 { f64(viewport.last_draw_rect.w), f64(viewport.last_draw_rect.h)}
	if event.sdl_event.type == SDL.EventType.PINCH_BEGIN {
		current_scale = 1
		pinch := event.sdl_event.pinch
		fmt.println("pinch begin:", pinch)
	}
	if event.sdl_event.type == SDL.EventType.PINCH_UPDATE {
		pinch := event.sdl_event.pinch
		fmt.println("pinch update:", pinch)
		scale := f64(pinch.scale / current_scale)
		current_scale = pinch.scale
		
		scale = math.pow(scale, SCALE_POWER)
		//scale = 1 / scale

		viewport.basis_x *= scale
		viewport.basis_y *= scale

		mouse_model_pos := view_to_model(viewport, vp_size, mouse_coords)

		viewport.origin += (viewport.origin - mouse_model_pos) * (1-scale)
	}
	if event.sdl_event.type == SDL.EventType.PINCH_END {
		current_scale = 1
		pinch := event.sdl_event.pinch
		fmt.println("pinch end:", pinch)
	}
	
	if event.sdl_event.type == .MOUSE_WHEEL {
		wheel_evt := (^SDL.MouseWheelEvent)(event.sdl_event)


		if wheel_evt.source != .TOUCH && wheel_evt.source != .CONTINUOUS {
			scale := math.pow(1.1, f64(wheel_evt.y))
			viewport.basis_x *= scale
			viewport.basis_y *= scale

			mouse_coords := linalg.round([2]f32{wheel_evt.mouse_x, wheel_evt.mouse_y})
			mouse_model_pos := view_to_model(viewport, vp_size, mouse_coords)

			viewport.origin += (viewport.origin - mouse_model_pos) * (1-scale)
		} else { // wheel_evt.source == .TOUCH
			
			PAN_SCALE :: 50 // pixels per scroll unit

			span_x := viewport.basis_x
			span_y := viewport.basis_y
			if span_x.x != 0 {span_x.x = 1/ span_x.x}
			if span_x.y != 0 {span_x.y = 1/ span_x.y}
			if span_y.x != 0 {span_y.x = 1/ span_y.x}
			if span_y.y != 0 {span_y.y = 1/ span_y.y}

			viewport.origin += f64(wheel_evt.x) * span_x * PAN_SCALE
			viewport.origin += f64(wheel_evt.y) * span_y * PAN_SCALE * -1
		}

	}



	if event.sdl_event.type == .MOUSE_BUTTON_DOWN {
		mouse_pressed = true
		mouse_btn_evt := (^SDL.MouseButtonEvent)(event.sdl_event)
		mouse_coords = linalg.round([2]f32{mouse_btn_evt.x, mouse_btn_evt.y})

		model_coords := view_to_model(viewport, vp_size, mouse_coords)
		grab_coords = model_coords
	}
	if event.sdl_event.type == .MOUSE_BUTTON_UP {
		mouse_pressed = false
	}
	if event.sdl_event.type == .MOUSE_MOTION {
		mouse_motion := (^SDL.MouseMotionEvent)(event.sdl_event)
		mouse_coords = linalg.round([2]f32{mouse_motion.x, mouse_motion.y})
		model_coords := view_to_model(viewport, vp_size, mouse_coords)

		if mouse_pressed {
			delta := model_coords - grab_coords
			viewport.origin -= delta
		}
	}
}

tex_new_ui: ^SDL.Texture

counter: i32 = 0
toogle: bool = false

iterate :: proc() {

	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
	SDL.RenderClear(ab.renderer)
	ui.ui_idle(0.01);
	ui.layout_begin({f32(ab.win_size.x), f32(ab.win_size.y)}, ab.dpi)
	/////////////////////////////////////

	// ui.layout_container(ui.Layout_Linear_Horizontal{})
	// layout_viewport()
	// layout_layers()
	// ui.layout_close()

	ui.panels_present_layout(panels)

	/////////////////////////////////////////
	ui.layout_end()
	ab.render_layout(&ui.render_commands)

	if tex_new_ui == nil {
		tex_new_ui = SDL.CreateTexture(ab.renderer, .RGBA8888, .TARGET, 4096, 4096)
	}

	SDL.SetRenderTarget(ab.renderer, tex_new_ui)
		SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 0)
		SDL.RenderClear(ab.renderer)
		layout_draw()
	SDL.SetRenderTarget(ab.renderer, nil)

	r := SDL.FRect {0, 0, f32(ab.win_size.x), f32(ab.win_size.y)}
	//SDL.SetTextureAlphaModFloat(tex_new_ui, 0.5)

	counter += 1
	if counter % 60 == 0 {
		toogle = !toogle
	}

	if toogle {
		SDL.RenderTexture(ab.renderer, tex_new_ui, &r, &r )
	}

	SDL.SetTextureAlphaModFloat(tex_new_ui, 1)
	
	ab.draw_present()

	err := SDL.GetError()
	if (err != nil && len(err) != 0) {
		fmt.println(err)

	}
}

layout_draw :: proc() {
	corners := ab.CornerRadii {4,4,4,4}
	num_items := len(ui.layout_state.items_tree)
	for idx in 0..<num_items {
		decl := ui.layout_state.items_decl[idx]
		item := ui.layout_state.items_tree[idx]
		if item.color.a != 0 {
			rect := transmute(ab.Rect)item.layout_rect
			SDL.SetRenderDrawColorFloat(ab.renderer, 1, 1, 1, 1)
			SDL.SetRenderColorScale(ab.renderer, 1)
			SDL.SetRenderDrawBlendMode(ab.renderer, {.BLEND})

			c := item.color
			c.a = 1

			rect2 := transmute(SDL.FRect) rect
			//SDL.RenderFillRect(ab.renderer, &rect2)

			if decl.override.type == ui.BoxStyleColored {
				box_style := (^ui.BoxStyleColored)(decl.override.data)
				ui.draw_box_styled(rect, box_style^)
			} else if decl.override.type == ui.BoxStyle {
				box_style := (^ui.BoxStyle)(decl.override.data)
				#partial switch v in box_style {
					case ui.BoxStyleColored:
						ui.draw_box_styled(rect, v)
				}
			} else {
				ab.draw_box_filled(rect, corners, c)
			}

			
			//fmt.println(rect, corners, item.color)
		}
		if decl.is_text {
			cstr := cstring(raw_data(decl.text))
		    sdl_text := ui.get_text_with_font_size(decl.text_font, decl.text_size)
			TTF.SetTextString(sdl_text, cstr, uint(len(decl.text)))
			TTF.DrawRendererText(sdl_text, f32(item.layout_rect.x), f32(item.layout_rect.y))
		}
	}
}

viewport_render_data := ab.CustomRenderData {
	callback = draw_viewport
}

layout_viewport :: proc () {

	ui.ui_pointer_handler(my_handler)

	clay.UI(clay.ID("viewport-content"))(
			{
				layout = {
					sizing = {
						width = clay.SizingGrow(),
						height = clay.SizingGrow(),
					},
				},
				backgroundColor = {1, 1, 1, 1},
				custom = {&viewport_render_data},
			},
	)
}

skip_viewport := true

draw_viewport :: proc(render_data: ^ab.CustomRenderData, render_command: ^clay.RenderCommand) {

	if skip_viewport {
		return
	}
	box := render_command.boundingBox
	viewport.last_draw_rect = transmute(ab.Rect)(box)

	ab.draw_set_draw_rect(ab.renderer, {i32(box.x), i32(box.y)}, {i32(box.width), i32(box.height)} )

	SDL.SetRenderDrawColorFloat(ab.renderer, 0, 0, 0, 1)

	rect := transmute(SDL.FRect) box
	SDL.RenderFillRect(ab.renderer, &rect)

	if model_loaded {
		viewport.data = &model
		vp_draw(viewport)
	}

	ab.draw_clear_draw_rect(ab.renderer)
}


layer_toggle_vis :: proc(layer_idx: int) {
	fmt.println("toggle layer:", layer_idx)
}

layer_change_color :: proc(layer_name: string) {
	fmt.println("layer color:", layer_name)
}


layout_layers :: proc() {
	ui.layout_scrollview()
	ui.layout_container(ui.Layout_Linear_Vertical{2, {}}, nil, "layers")

	if model_loaded {
		for layer_idx in 0..<len(model.dxf.layers) {
			layer := model.dxf.layers[layer_idx]
			ui.layout_container(ui.Layout_Linear_Horizontal{})
				ui.layout_button("O", layer_idx, layer_toggle_vis)

				ui.layout_linear_child(ui.LinearChildSizingFixed{width = {type = .Weight, amount=1,flags={.Debug}}, height={type=.Fit}, across=.Center})
				ui.layout_container(ui.Layout_Extend{})
					ui.layout_text(layer.name)
				ui.layout_close()
				ui.layout_button("", layer.name, layer_change_color)
			ui.layout_close()
		}
	}
	ui.layout_close()

	ui.layout_close()
}

layout_statusbar :: proc() {
	ui.layout_container(ui.Layout_Linear_Horizontal{}, nil, "statusbar")

	ui.layout_button("status bar content")

	ui.layout_close()
}


lerp :: proc(a, b: f64x3, t: f64) -> f64x3 {
	t1 := f64(t)
	return a * (1.0 - t1) + b * t1
}
