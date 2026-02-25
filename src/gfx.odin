
package main

import SDL "vendor:sdl3"

import "core:log"
import "core:math"
import "core:math/linalg"

import clay "clay-odin"

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

Rect :: clay.BoundingBox

draw_box_filled :: proc (box: Rect, rect: clay.RectangleRenderData) {

	vertices_buf: [1000]vec2
	uvs_buf: [1000]vec2
	indices_buf: [2000]u8

	num_vertices: i32 = 0
	num_indices: i32 = 0

	corners := rect.cornerRadius

	// center full rect
	PAD :: 1 // expand for antialiasing

	//HALF_PIXEL :: vec2{0.5, 0.5}
	boxmin := vec2{box.x,             box.y}
	boxmax := vec2{box.x + box.width, box.y + box.height}

	topleft  := vec2{boxmin.x + corners.topLeft, boxmin.y + corners.topLeft}
	topright := vec2{boxmax.x - corners.topRight, boxmin.y + corners.topRight}
	botleft  := vec2{boxmin.x + corners.bottomLeft, boxmax.y - corners.bottomLeft}
	botright := vec2{boxmax.x - corners.bottomRight, boxmax.y - corners.bottomRight}

	vertices_buf[0] = topleft
	vertices_buf[1] = topright
	vertices_buf[2] = botleft
	vertices_buf[3] = botright

//	uv_center := ZERO_PIX_CLAMP + (PIXEL_Y * (width+1) * 0.5)
	uv_outer :=  ZERO_PIX_CLAMP + (PIXEL_Y * (0.5 - PAD))
//	log.info(uv_outer)

	uvs_buf[0] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.topLeft + 0.5))
	uvs_buf[1] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.topRight + 0.5))
	uvs_buf[2] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.bottomLeft + 0.5))
	uvs_buf[3] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.bottomRight + 0.5))


	indices_buf[0] = 0
	indices_buf[1] = 1
	indices_buf[2] = 2
	indices_buf[3] = 1
	indices_buf[4] = 2
	indices_buf[5] = 3

	// top bottom left right rectangles

	vertices_buf[4] = {topleft.x,  boxmin.y - PAD}
	vertices_buf[5] = {topright.x, boxmin.y - PAD}

	vertices_buf[6] = {botleft.x,  boxmax.y + PAD}
	vertices_buf[7] = {botright.x, boxmax.y + PAD}

	vertices_buf[8] = {boxmin.x - PAD,  topleft.y}
	vertices_buf[9] = {boxmin.x - PAD,  botleft.y}

	vertices_buf[10] = {boxmax.x + PAD,  topright.y}
	vertices_buf[11] = {boxmax.x + PAD,  botright.y}

	uvs_buf[4] = uv_outer
	uvs_buf[5] = uv_outer
	uvs_buf[6] = uv_outer
	uvs_buf[7] = uv_outer
	uvs_buf[8] = uv_outer
	uvs_buf[9] = uv_outer
	uvs_buf[10] = uv_outer
	uvs_buf[11] = uv_outer


	num_vertices = 12

	indices_buf[6] = 0
	indices_buf[7] = 4
	indices_buf[8] = 5
	indices_buf[9] = 0
	indices_buf[10] = 5
	indices_buf[11] = 1

	indices_buf[12] = 2
	indices_buf[13] = 3
	indices_buf[14] = 6
	indices_buf[15] = 3
	indices_buf[16] = 6
	indices_buf[17] = 7

	indices_buf[18] = 0
	indices_buf[19] = 2
	indices_buf[20] = 8
	indices_buf[21] = 2
	indices_buf[22] = 8
	indices_buf[23] = 9

	indices_buf[24] = 1
	indices_buf[25] = 3
	indices_buf[26] = 10
	indices_buf[27] = 3
	indices_buf[28] = 10
	indices_buf[29] = 11

	num_indices = 30

	// rounded corners

	draw_rounded_corner(vertices_buf[:], indices_buf[:], uvs_buf[:], &num_vertices, &num_indices,0, 8, 4)
	draw_rounded_corner(vertices_buf[:], indices_buf[:], uvs_buf[:], &num_vertices, &num_indices,1, 5, 10)
	draw_rounded_corner(vertices_buf[:], indices_buf[:], uvs_buf[:], &num_vertices, &num_indices,3, 11, 7)
	draw_rounded_corner(vertices_buf[:], indices_buf[:], uvs_buf[:], &num_vertices, &num_indices,2, 6, 9)

	//num_vertices = i32(start_vert)
	//num_indices = start_idx + 12

	// submit
	fcolor := SDL.FColor(rect.backgroundColor)
	SDL.SetRenderTextureAddressMode(renderer, .CLAMP, .CLAMP)

	SDL.RenderGeometryRaw(
		renderer,
		helper, // texture
		&vertices_buf[0][0], 8, // verts, stride
		&fcolor, 0, // color, stride
		&uvs_buf[0][0], 8, // uvs
		num_vertices,
		&indices_buf, num_indices, 1
	)

	/*
	SDL.SetRenderDrawColor(renderer, 255, 0, 0, 50)
	rect := SDL.FRect{
		box.x, box.y, box.width, box.height
	}
	SDL.RenderRect(renderer, &rect)
*/
}


draw_rounded_corner :: proc (
	vertices_buf: []vec2, indices_buf: []u8, uvs_buf: []vec2,
	ptr_num_vertices: ^i32, ptr_num_indices: ^i32,
	pivot_idx: u8, left_idx: u8, right_idx: u8) {

	origin := vertices_buf[pivot_idx]
	start_pos := vertices_buf[left_idx] - origin

	border_uv := uvs_buf[left_idx]

	num_vertices := ptr_num_vertices^
		num_indices := ptr_num_indices^

	segments: u8
	radius: f32 = math.abs(start_pos.x) + math.abs(start_pos.y)

	segments = u8(math.min(127, math.floor(radius/math.ln(radius*1.6+1))))
	if segments < 2 {
		segments = 2
	}
	//log.info("segments", segments)
	delta_angle := (math.TAU/4) / f32(segments)
	mat_cos := math.cos(delta_angle)
	mat_sin := math.sin(delta_angle)

	start_vert := u8(num_vertices)
	start_idx := num_indices

	vert_pos := start_pos

	for segment in 1..<segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[num_vertices] = origin + vert_pos
		uvs_buf[num_vertices] = border_uv
		num_vertices += 1
	}

	indices_buf[num_indices] = pivot_idx
	indices_buf[num_indices+1] = left_idx
	indices_buf[num_indices+2] = start_vert
	num_indices += 3

	for segment in 2..<segments {

		indices_buf[num_indices] = pivot_idx
		indices_buf[num_indices+1] = start_vert + segment - 2
		indices_buf[num_indices+2] = start_vert + segment - 1
		num_indices += 3
	}

	indices_buf[num_indices] = pivot_idx
	indices_buf[num_indices+1] = start_vert + segments - 2
	indices_buf[num_indices+2] = right_idx
	num_indices += 3

	ptr_num_vertices^ = num_vertices
	ptr_num_indices^ = num_indices

}


draw_box_border :: proc (box: clay.BoundingBox, border: clay.BorderRenderData) {

	ab_box := [4]f32 {
		box.x, box.y, box.width, box.height,
	}

	borderwidth := border.width
	ab_border := [4]f32 {
		f32(borderwidth.left),
		f32(borderwidth.right),
		f32(borderwidth.top),
		f32(borderwidth.bottom),
	}

	corners := border.cornerRadius
	ab_corners := [4]f32 {
		corners.topLeft, corners.topRight, corners.bottomLeft, corners.bottomRight
	}
	draw_box_border2(renderer, ab_box, border.color, ab_border, ab_corners)
}

draw_box_border2 :: proc (renderer: ^SDL.Renderer, rect: [4]f32, color: [4]f32, borders: [4]f32, in_corners: [4]f32) {
	box := clay.BoundingBox{rect[0], rect[1], rect[2], rect[3]}
	corners := clay.CornerRadius{in_corners[0], in_corners[1], in_corners[2], in_corners[3]}

    SDL.SetRenderDrawColorFloat(renderer, color[0], color[1], color[2], color[3])
	SDL.SetRenderDrawBlendMode(renderer, {.BLEND})

    rect2: SDL.FRect

	BORDER_LEFT :: 0
	BORDER_RIGHT :: 1
	BORDER_TOP :: 2
	BORDER_BOTTOM :: 3

	// top border
	rect2.y = box.y
	rect2.h = borders[BORDER_TOP]
	rect2.x = box.x + corners.topLeft
	rect2.w = box.width - corners.topLeft - corners.topRight
	SDL.RenderFillRect(renderer, &rect2)

	// bottom border
	rect2.y = box.y + box.height - borders[BORDER_BOTTOM]
	rect2.h = borders[BORDER_BOTTOM]
	rect2.x = box.x + corners.bottomLeft
	rect2.w = box.width - corners.bottomLeft - corners.bottomRight
	SDL.RenderFillRect(renderer, &rect2)

	// left border
	rect2.y = box.y + corners.topLeft
	rect2.h = box.height - corners.topLeft - corners.bottomLeft
	rect2.w = borders[BORDER_LEFT]
	rect2.x = box.x
	SDL.RenderFillRect(renderer, &rect2)

	// right border
	rect2.y = box.y + corners.topRight
	rect2.h = box.height - corners.topRight - corners.bottomRight
	rect2.x = box.x + box.width - borders[BORDER_RIGHT]
	rect2.w = borders[BORDER_RIGHT]
    SDL.RenderFillRect(renderer, &rect2)

	segments :: 4 // maybe calculate based on perimeter and pixel precision?
	angle: f32 = math.TAU / 2

	fcolor := SDL.FColor(color)
	// antialias stencil is drawn as premultiplied
	fcolor.r *= fcolor.a
	fcolor.g *= fcolor.a
	fcolor.b *= fcolor.a

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


	if corners.topLeft != 0 {
		draw_rounded_border(&buffer, borders[BORDER_TOP], borders[BORDER_LEFT], corners.topLeft, 0, {box.x, box.y})
	}
	if corners.topRight != 0 {
		draw_rounded_border(&buffer, borders[BORDER_TOP], borders[BORDER_RIGHT], corners.topRight, 1, {box.x+box.width, box.y})
	}
	if corners.bottomLeft != 0 {
		draw_rounded_border(&buffer, borders[BORDER_BOTTOM], borders[BORDER_LEFT], corners.bottomLeft, 2, {box.x, box.y+box.height})
	}
	if corners.bottomRight != 0 {
		draw_rounded_border(&buffer, borders[BORDER_BOTTOM], borders[BORDER_RIGHT], corners.bottomRight, 3, {box.x+box.width, box.y+box.height})
	}

	SDL.RenderGeometryRaw(
		renderer,
		helper, // texture
		&buffer.vertices[0][0], 8, // verts + stride
		&fcolor, 0, // color + stride
		&buffer.uvs[0][0], 8, // uvs
		buffer.num_vertices,
		&buffer.indices[0], buffer.num_indices,
		1,
	)

	/*
	Sdl.SetRenderDrawColor(renderer, 255, 0, 0, 80)
	full := SDL.FRect{box.x, box.y, box.width, box.height}
    SDL.RenderRect(renderer, &full)

	SDL.SetRenderDrawColor(renderer, 0, 255, 0, 80)
	safe := SDL.FRect{
		box.x + borders[left),
		box.y + borders[top),
		box.width - borders[left) - borders[right),
		box.height - borders[bottom) - borders[top),
	}
    SDL.RenderRect(renderer, &safe)
*/
}

DrawBuffer :: struct {
	num_vertices: i32,
	num_indices: i32,
	vertices: []vec2,
	uvs: []vec2,
	colors: [][4]f32,
	indices: []u8,
}



// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
draw_rounded_border :: proc (buffer: ^DrawBuffer, width_h: f32, width_v: f32, radius: f32, corner_idx: int, corner: vec2) {
	segments  := u8(math.min(30, math.floor(radius/math.ln(radius*1.6+1))))
	vertices_buf := buffer.vertices[buffer.num_vertices:]
	uvs_buf := buffer.uvs[buffer.num_vertices:]
	indices_buf := buffer.indices[buffer.num_indices:]

	num_vertices : i32 = i32(segments) * 2 + 2
	num_indices : i32 = i32(segments) * 6
	start_index := u8(buffer.num_vertices)

	buffer.num_vertices += num_vertices
	buffer.num_indices += num_indices

	PAD :: 1

	keep_x := width_v > radius
	keep_y := width_h > radius

	flip := vec2{1, 1}
	// corners 0 and 2 are in the left, so centerpoint is to the right
	if corner_idx % 2 == 0 {
		flip.x *= -1
	}

	// corners 0 and 1 are in the top, so centerpoint is below
	if corner_idx & 2 == 0 {
		flip.y *= -1
	}

	centerpoint := corner - (flip * radius)

	v_radius := flip * (radius + PAD)
	v_radius_inner := flip * vec2{radius-width_v-PAD, radius-width_h-PAD}

	// draw from centerpoint +- x to centerpoint +- y
	STROKE_OFFSET :: 0
	STROKE_CONTRAST :: 1.4 // a way to compensate for gamma-blended lines,
	base := vec2{0.5, 0.5} / TEX_SIZE + STROKE_OFFSET


	uv_outer :f32 = (0.5 - PAD) * STROKE_CONTRAST

	uv_innerh :f32 = (width_h + PAD + 0.5 ) * STROKE_CONTRAST
	uv_innerv :f32 = (width_v + PAD + 0.5 ) * STROKE_CONTRAST

	uvs_buf[0] = base + ({uv_outer, uv_innerv} / TEX_SIZE)
	uvs_buf[1] = base + ({uv_innerv, uv_outer} / TEX_SIZE)

	vertices_buf[0] = { centerpoint.x + v_radius.x,       centerpoint.y }
	vertices_buf[1] = { centerpoint.x + v_radius_inner.x, keep_y ? corner.y + width_h : centerpoint.y }
	increment := math.TAU / 4 / f32(segments)
	mat_cos := math.cos(increment)
	mat_sin := math.sin(increment)

	vert_pos := vec2{1, 0}
	for idx in 1..<segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx*2] = centerpoint + (vert_pos * v_radius)
		vertices_buf[idx*2+1] = centerpoint + ([2]f32{
			keep_x ? 1.0 : vert_pos.x,
			keep_y ? 1.0 : vert_pos.y,
		} * v_radius_inner)
		uvs_buf[idx*2] = base + ({uv_outer, uv_innerv* vert_pos.x* vert_pos.x + uv_innerh * vert_pos.y* vert_pos.y} / TEX_SIZE)
		uvs_buf[idx*2+1] = base + ({uv_innerv* vert_pos.x* vert_pos.x + uv_innerh * vert_pos.y * vert_pos.y, uv_outer} / TEX_SIZE)
	}
	vertices_buf[segments*2] =   { centerpoint.x, centerpoint.y + v_radius.y }
	vertices_buf[segments*2+1] = { keep_x ? corner.x + width_v : centerpoint.x, centerpoint.y + v_radius_inner.y}

	uvs_buf[segments*2] = base + ({uv_outer, uv_innerh} / TEX_SIZE)
	uvs_buf[segments*2+1] = base + ({uv_innerh, uv_outer} / TEX_SIZE)


	for idx_wide in 0..<segments {
		idx := u8(idx_wide)
		indices_buf[idx * 6]     = start_index + idx * 2
		indices_buf[idx * 6 + 1] = start_index + idx * 2 + 1
		indices_buf[idx * 6 + 2] = start_index + idx * 2 + 2
		indices_buf[idx * 6 + 3] = start_index + idx * 2 + 2
		indices_buf[idx * 6 + 4] = start_index + idx * 2 + 1
		indices_buf[idx * 6 + 5] = start_index + idx * 2 + 3
	}
}
