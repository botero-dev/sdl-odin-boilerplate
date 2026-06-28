package gfx

import "core:log"

import SDL "vendor:sdl3"

TEX_SIZE :: 2
ZERO_PIX_CLAMP := f32x2{0.5, 1.5} / TEX_SIZE
PIXEL_X := f32x2{1, 0} / TEX_SIZE
PIXEL_Y := f32x2{1, 0} / TEX_SIZE

helper: ^SDL.Texture


txv :: proc(vert: f32x2) -> f32x2 {
	vert3 := [3]f32{vert.x, vert.y, 1}
	vert3 = draw_state.user_matrix * vert3
	return vert3.xy
}

DrawState :: struct {
	line_scale:  f32,
	mat_scale:   [2]f32,
	mat_offset:  [2]f32,
	draw_rect:   [2][2]i32, // encoded as x,y  w,h
	view_mode:   View_Mode,
	user_matrix: matrix[3, 3]f32,
	modulate:    [4]f32,
}

draw_state_stack: [dynamic]DrawState

draw_state_initial := DrawState {
	line_scale  = 0,
	mat_scale   = {1, 1},
	mat_offset  = {0, 0},
	draw_rect   = {},
	view_mode   = {},
	user_matrix = 1,
	modulate    = {1, 1, 1, 1},
}

draw_state := draw_state_initial
draw_matrix: matrix[3, 3]f32 = 1

draw_push_state :: proc() {
	append(&draw_state_stack, draw_state)
}

draw_pop_state :: proc() {
	reverting_draw_state := pop(&draw_state_stack)

	if reverting_draw_state.draw_rect != draw_state.draw_rect {
		rect_size := reverting_draw_state.draw_rect[1]
		if rect_size == {} {
			SDL.SetRenderClipRect(renderer, nil)
		} else {
			rect_pos := reverting_draw_state.draw_rect[0]
			clip_rect := SDL.Rect {
				x = rect_pos.x,
				y = rect_pos.y,
				w = rect_size.x,
				h = rect_size.y,
			}
			SDL.SetRenderClipRect(renderer, &clip_rect)
		}
	}

	draw_state = reverting_draw_state
	update_matrix()
}

draw_present :: proc() {
	if len(draw_state_stack) != 0 {
		log.warn("Draw State Stack should be empty when presenting.")
	}
	SDL.RenderPresent(renderer)
}

draw_set_matrix :: proc(in_user_matrix: matrix[3, 3]f32) {
	draw_state.user_matrix = in_user_matrix
	draw_state.user_matrix[0][2] = 0
	draw_state.user_matrix[1][2] = 0
	draw_state.user_matrix[2][2] = 1
	update_matrix()
}

draw_clear_matrix :: proc() {
	draw_state.user_matrix = 1
	update_matrix()
}

// if set to zero, line width means physical pixels, otherwise it means a unit relative to the view rect
draw_set_line_scale :: proc(scale: f32) {
	draw_state.line_scale = scale
}

draw_set_draw_rect :: proc(renderer: ^SDL.Renderer, position: [2]i32, size: [2]i32) {

	draw_state.draw_rect = {position, size}
	clip_rect := SDL.Rect {
		x = (position.x),
		y = (position.y),
		w = (size.x),
		h = (size.y),
	}
	SDL.SetRenderClipRect(renderer, &clip_rect)
	update_matrix()
}

draw_clear_draw_rect :: proc(renderer: ^SDL.Renderer) {
	draw_state.draw_rect = {}
	SDL.SetRenderClipRect(renderer, nil)
	update_matrix()
}

draw_clear_view_rect :: proc() {
	draw_state.view_mode = {}
	draw_state.mat_scale = {1, 1}
	draw_state.mat_offset = {0, 0}
}



View_Scaling :: enum {
	Stretch,
	Fit,
	Fill,
}

View_Mode_Rect :: struct {
	scaling: View_Scaling,
	topleft: f32x2,
	botright: f32x2,
}

View_Mode_Basis :: struct {
	centerpoint: f32x2,
	right: f32x2,
	up: f32x2,
}

View_Mode :: union {
	View_Mode_Rect,
	View_Mode_Basis,
}

draw_set_view_rect :: proc(view_topleft: f32x2, view_botright: f32x2, scaling: View_Scaling = .Stretch) {
	draw_state.view_mode = View_Mode_Rect{scaling, view_topleft, view_botright}
	update_matrix()
}

// absolute projection, vectors are interpreted as pixels:
// so {100, 20) would make a unit be displaced that amount in pixels
draw_set_view_basis :: proc(right: f32x2, up: f32x2, centerpoint: f32x2) {
	draw_state.view_mode = View_Mode_Basis{centerpoint, right, up}
	update_matrix()
}

update_matrix :: proc() {
	draw_rect := draw_state.draw_rect
	draw_size := draw_rect[1]
	if draw_size == {0, 0} {
		// TODO: maybe find current framebuffer size before?
		draw_size = {win_size.x, win_size.y}
	}
	
	switch view_mode in draw_state.view_mode {
		case View_Mode_Rect:
			view_rect := view_mode
			view_topleft := view_rect.topleft
			view_botright := view_rect.botright
			if view_topleft == {} && view_botright == {} {
				draw_state.mat_scale = {1, 1}
				draw_state.mat_offset = {0, 0}
				return
			}

			view_range := view_botright - view_topleft

			draw_pos := f32x2{f32(draw_rect[0].x), f32(draw_rect[0].y)}
			draw_state.mat_scale = f32x2{f32(draw_size.x), f32(draw_size.y)} / view_range
			draw_state.mat_offset = draw_pos - (view_topleft * draw_state.mat_scale)

			draw_matrix = (matrix[3, 3]f32{
						draw_state.mat_scale.x, 0, draw_state.mat_offset.x,
						0, draw_state.mat_scale.y, draw_state.mat_offset.y,
						0, 0, 1,
					})

			draw_matrix = draw_matrix * draw_state.user_matrix

		case View_Mode_Basis:

			view_mode_basis := View_Mode_Basis(view_mode)

			draw_matrix = 1;
			
			offset :=  view_mode_basis.centerpoint
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

			scale_mat[0] = {view_mode.right.x, view_mode.right.y, 0}
			scale_mat[1] = {view_mode.up.x, view_mode.up.y, 0}

			draw_matrix = scale_mat * draw_matrix

			midpoint := draw_size / 2

			midpoint += draw_rect[0]
			center := [2]f32{f32(midpoint.x), f32(midpoint.y)}

			draw_matrix =  matrix[3,3]f32 {
				1, 0, center.x,
				0, 1, center.y,
				0, 0, 1,
			} * draw_matrix

			draw_matrix = draw_matrix * draw_state.user_matrix
	}
}


uvs_buf: [1000]f32x2
indices_buf: [2000]u8
