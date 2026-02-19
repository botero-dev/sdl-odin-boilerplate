
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

draw_line_scale: f32 = 0

// if set to zero, line width means physical pixels, otherwise it means a unit relative to the view rect
draw_set_line_scale :: proc(scale: f32) {
	draw_line_scale = scale
}

draw_pos: vec2
draw_size: vec2

draw_set_draw_rect :: proc(renderer: ^SDL.Renderer, position: vec2, size: vec2) {
	draw_pos = position
	draw_size = size
	clip_rect := SDL.Rect {
		x = i32(draw_pos.x),
		y = i32(draw_pos.y),
		w = i32(draw_size.x),
		h = i32(draw_size.y),
	}
	SDL.SetRenderClipRect(renderer, &clip_rect)
}

draw_clear_draw_rect :: proc(renderer: ^SDL.Renderer) {
	draw_pos = {0, 0}
	draw_size = {f32(win_size.x), f32(win_size.y)}
	SDL.SetRenderClipRect(renderer, nil)
}

draw_clear_view_rect :: proc() {
	mat_scale = {1,1}
	mat_offset = {0,0}
}

mat_scale: vec2 = {1,1}
mat_offset: vec2 = {0,0}

draw_set_view_rect :: proc(vp_topleft: vec2, vp_botright: vec2) {

	if draw_size == {0, 0} {
		draw_size = {f32(win_size.x), f32(win_size.y)}
	}

	range := vp_botright - vp_topleft
	mat_scale = draw_size / range
	mat_offset = draw_pos -(vp_topleft*mat_scale)
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

	center := in_center * mat_scale + mat_offset
	radius := in_radius * mat_scale.x
	buffer_circle(&buffer, center, radius, int_coords)

	buffer.vertices = buffer.vertices[:buffer.num_vertices]
	buffer.indices = buffer.indices[:buffer.num_indices]
	buffer.uvs = buffer.uvs[:buffer.num_vertices]

	draw_buffer(renderer, &buffer, in_color)
}

// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
buffer_circle :: proc (buffer: ^DrawBuffer, in_center: vec2, in_radius: f32, int_coords: bool = false) {

	center := in_center
	radius := in_radius
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

	vert_pos := vec2{radius+PAD, 0}
	vertices_buf[0] = center
	vertices_buf[1] = center + vert_pos
	uvs_buf[0] = helper_uv({1,1})
	uvs_buf[1] = helper_uv({1, 0.5 - (0.5*PAD/radius)})

	for idx in 2..=segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx] = center + vert_pos
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

	if draw_line_scale != 0 {
		width *= draw_line_scale * mat_scale.x
	}

	start = start * mat_scale + mat_offset
	end = end * mat_scale + mat_offset

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
