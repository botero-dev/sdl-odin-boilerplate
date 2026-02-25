
package main

import SDL "vendor:sdl3"

import "core:log"
import "core:math"
import "core:math/linalg"

helper: ^SDL.Texture
helper_dot: ^SDL.Texture

TEX_SIZE :: 2
ZERO_PIX_CLAMP := vec2{0.5, 1.5} / TEX_SIZE
PIXEL_X := vec2{1, 0} / TEX_SIZE
PIXEL_Y := vec2{1, 0} / TEX_SIZE


gfx_init :: proc () {
	helper = SDL.CreateTexture(renderer, .RGBA32, .TARGET, 2, 2)
	SDL.SetRenderTarget(renderer, helper)
	SDL.SetRenderDrawColorFloat(renderer, 0, 0, 0, 0)
	SDL.RenderClear(renderer)
	SDL.SetRenderDrawColorFloat(renderer, 1,1,1,1)
	SDL.RenderPoint(renderer, 1, 1)
	SDL.SetTextureScaleMode(helper, .PIXELART)
	SDL.SetTextureBlendMode(helper, {.BLEND_PREMULTIPLIED})

	/*
	helper_dot = SDL.CreateTexture(renderer, .RGBA32, .TARGET, 3, 3)
	SDL.SetRenderTarget(renderer, helper)
	SDL.SetRenderDrawColorFloat(renderer, 0, 0, 0, 0)
	SDL.RenderClear(renderer)
	SDL.SetRenderDrawColorFloat(renderer, 1,1,1,1)
	SDL.RenderPoint(renderer, 1, 1)
	SDL.SetTextureScaleMode(helper, .PIXELART)
	SDL.SetTextureBlendMode(helper, {.BLEND_PREMULTIPLIED})

	SDL.SetRenderTarget(renderer, nil)
 */
}

helper_uv :: proc (input: vec2) -> vec2 { return (input + 0.5) * 0.5  } // coord + half pixel / tex_size


DrawState :: struct {
	line_scale: f32,
	mat_scale: [2]f32,
	mat_offset: [2]f32,
	draw_rect: [2][2]i32, // encoded as x,y  w,h
	view_rect: [2]vec2,   // encoded as topleft, botright
	user_matrix: matrix[3,3]f32,
}

draw_state_stack: [dynamic]DrawState

draw_state_initial := DrawState {
	line_scale = 0,
	mat_scale = {1, 1},
	mat_offset = {0, 0},
	draw_rect = {},
	view_rect = {},
	user_matrix = 1,
}

draw_state := draw_state_initial
draw_matrix: matrix[3,3]f32 = 1

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
}

draw_present :: proc() {
	if len(draw_state_stack) != 0 {
		log.warn("Draw State Stack should be empty when presenting.")
	}
	SDL.RenderPresent(renderer)
}

draw_set_matrix :: proc(in_user_matrix: matrix[3,3]f32) {
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
	draw_state.view_rect = {}
	draw_state.mat_scale = {1,1}
	draw_state.mat_offset = {0,0}
}

draw_set_view_rect :: proc(view_topleft: vec2, view_botright: vec2) {
	draw_state.view_rect = {view_topleft, view_botright}
	update_matrix()
}

update_matrix :: proc() {
	view_topleft := draw_state.view_rect[0]
	view_botright := draw_state.view_rect[1]
	if view_topleft == {} && view_botright == {} {
		draw_state.mat_scale = {1,1}
		draw_state.mat_offset = {0,0}
		return
	}

	draw_rect := draw_state.draw_rect
	draw_size := draw_rect[1]
	if draw_size == {0, 0} {
		draw_size = {win_size.x, win_size.y}
	}
	view_range := view_botright - view_topleft

	draw_pos := vec2{f32(draw_rect[0].x), f32(draw_rect[0].y)}
	draw_state.mat_scale = vec2{f32(draw_size.x), f32(draw_size.y)} / view_range
	draw_state.mat_offset = draw_pos - (view_topleft * draw_state.mat_scale)

	draw_matrix = (matrix[3,3]f32{
		draw_state.mat_scale.x, 0, draw_state.mat_offset.x,
		0, draw_state.mat_scale.y, draw_state.mat_offset.y,
		0, 0, 1,
	})

	draw_matrix = draw_matrix * draw_state.user_matrix
}



draw_circle :: proc(renderer: ^SDL.Renderer, in_center: vec2, in_radius: f32, in_color:[4]f32 = {1,1,1,1}, int_coords: bool = false) {
	vertices_buf: [1000]vec2
	uvs_buf: [1000]vec2
	indices_buf: [2000]u8

	buffer := DrawBuffer {
		0, 0,
		vertices_buf[:],
		uvs_buf[:],
		nil,
		indices_buf[:],
	}

	buffer_circle(&buffer, in_center, in_radius, int_coords)

	buffer.vertices = buffer.vertices[:buffer.num_vertices]
	buffer.indices = buffer.indices[:buffer.num_indices]
	buffer.uvs = buffer.uvs[:buffer.num_vertices]

	draw_buffer(renderer, &buffer, in_color)
}

// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
buffer_circle :: proc (buffer: ^DrawBuffer, in_center: vec2, in_radius: f32, int_coords: bool = false) {

	center := (draw_matrix * [3]f32{in_center.x, in_center.y, 1}).xy

	scale_mat := matrix[2,2]f32 {
		draw_matrix[0][0], draw_matrix[0][1],
		draw_matrix[1][0], draw_matrix[1][1],
	}
	radius := in_radius * linalg.length(scale_mat * [2]f32{1, 0})

	if int_coords {
		center += {0.5, 0.5}
		radius -= 0.5
	} // half pixel offset

	segments := i32( math.floor(radius*math.TAU/math.ln(radius*math.TAU*1.6+1)))
	segments = math.min(124, math.max(segments, 8))
	segments = i32(math.round(f32(segments) / 4)) * 4
	vertices_buf := buffer.vertices[buffer.num_vertices:]
	uvs_buf := buffer.uvs[buffer.num_vertices:]
	indices_buf := buffer.indices[buffer.num_indices:]

	num_vertices := segments + 1
	num_indices := segments * 3
	start_index := u8(buffer.num_vertices)

	buffer.num_vertices += num_vertices
	buffer.num_indices += num_indices


	PAD := f32(0.73) // lowest practical number, I guess the optimal thing could be sqrt(3)-1


	increment := math.TAU / f32(segments)
	mat_sin, mat_cos := math.sincos(increment)

	radius_pad := radius+PAD
	vert_pos := vec2{1, 0}

	vertices_buf[0] = center
	vertices_buf[1] = center + (vert_pos * scale_mat) // TODO: account for pad
	uvs_buf[0] = helper_uv({1,1})
	uvs_buf[1] = helper_uv({1, 0.5 - (0.5*PAD/radius)})

	for idx in 2..=segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx] = center + (vert_pos * scale_mat) // TODO: account for pad
		uvs_buf[idx] = uvs_buf[1]
	}

	STRIDE :: 3
	for idx_wide in 0..<segments {
		idx := u8(idx_wide)
		indices_buf[idx_wide * STRIDE]     = 0
		indices_buf[idx_wide * STRIDE + 1] = 1 + idx
		indices_buf[idx_wide * STRIDE + 2] = 2 + idx
	}
	indices_buf[(segments-1)*STRIDE+2] = 1 // last triangle end is actually first triangle begin
}


draw_line :: proc(renderer: ^SDL.Renderer, in_start: vec2, in_end: vec2, in_width: f32, in_color:[4]f32 = {1,1,1,1}) {
	vertices_buf: [1000]vec2
	uvs_buf: [1000]vec2
	indices_buf: [1000]u8

	buffer := DrawBuffer {
		0, 0,
		vertices_buf[:],
		uvs_buf[:],
		nil,
		indices_buf[:],
	}
	buffer_line(&buffer, in_start, in_end, in_width)
	draw_buffer(renderer, &buffer, in_color)
}

draw_buffer :: proc(renderer: ^SDL.Renderer, buffer: ^DrawBuffer, in_color: [4]f32) {

	fcolor := SDL.FColor{in_color[0], in_color[1], in_color[2], in_color[3]}

	//SDL.SetRenderTextureAddressMode(renderer, .CLAMP, .CLAMP)
	SDL.SetRenderTextureAddressMode(renderer, .WRAP, .WRAP)

	indices: rawptr = nil
	if buffer.indices != nil && len(buffer.indices) > 0 {
		indices = &buffer.indices[0]
	}
	SDL.RenderGeometryRaw(
		renderer,
		helper, // texture
		&buffer.vertices[0][0], 8, // verts + stride
		&fcolor, 0, // color + stride
		&buffer.uvs[0][0], 8, // uvs
		buffer.num_vertices,
		indices, buffer.num_indices,
		1,
	)
}

buffer_line :: proc(buffer: ^DrawBuffer, in_start: vec2, in_end: vec2, in_width: f32) {

	start := in_start
	end := in_end
	width := in_width

	if draw_state.line_scale != 0 {
		width *= draw_state.line_scale * draw_state.mat_scale.x
	}

	starta := [3]f32{start.x, start.y, 1}
	enda := [3]f32{end.x, end.y, 1}

	starta = draw_matrix * starta
	enda = draw_matrix * enda

	start = starta.xy
	end = enda.xy

	delta := end-start
	length := linalg.length(delta)
	dir := delta / length
	dir_side := vec2{dir.y, -dir.x}

	PAD :=  f32(0.5)
	side := dir_side * (width * 0.5 + PAD)

	vstart := start + vec2{0.5, 0.5} // offset to find pixel center
	vend := end + vec2{0.5, 0.5} // offset to find pixel center

	line_offset := dir * ((0.5 + PAD))
	line_start := vstart - line_offset
	line_end := vend + line_offset

	verts := []vec2{
		line_start - side,
		line_start + side,
		line_end - side,

		line_end + side,
		line_end - side,
		line_start + side,
	}

	indices := []u8{
		0, 1, 2, 3, 4, 5,
	}


	UV_OUTER := 0.5 - PAD
	UV_END := 0.5 + PAD
	uv_start := helper_uv({UV_OUTER, UV_OUTER})
	uv_length := helper_uv({length + 1 + UV_END, UV_OUTER})
	uv_width :=  helper_uv({UV_OUTER, width + UV_END})

	uvas := []vec2{
		uv_start,
		uv_width,
		uv_length,
		uv_start,
		uv_width,
		uv_length,
	}

	width_falloff := 0.5 / width
	length_falloff := 0.5 / length

	START := 0.5 - length_falloff
	END := 1.5 + length_falloff
	LEFT := 0.5 - width_falloff
	RIGHT := 1.5 + width_falloff

	uvs := []vec2{
		helper_uv({START, LEFT}),
		helper_uv({START, RIGHT}),
		helper_uv({END, LEFT}),
		helper_uv({END, RIGHT}),
		helper_uv({END, LEFT}),
		helper_uv({START, RIGHT}),
	}

	vertices_write := buffer.vertices[buffer.num_vertices:]
	uvs_write := buffer.uvs[buffer.num_vertices:]
	buffer.num_vertices += 6
	for idx in 0..<len(verts) {
		vertices_write[idx] = verts[idx]
		uvs_write[idx] = uvs[idx]
	}

	indices_write := buffer.indices[buffer.num_indices:]
	for idx in 0..<len(indices) {
		indices_write[idx] = indices[idx]
	}
	buffer.num_indices += i32(len(indices))
}
