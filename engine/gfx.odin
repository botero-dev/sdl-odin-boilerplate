
package engine

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"


import "core:log"
import "core:math"
import "core:math/linalg"

import m "math"

import "gfx"
import "ui"

DrawBuffer :: gfx.DrawBuffer
Rect :: m.Rect


renderer: ^SDL.Renderer
window: ^SDL.Window

TEX_SIZE :: 2
ZERO_PIX_CLAMP := vec2{0.5, 1.5} / TEX_SIZE
PIXEL_X := vec2{1, 0} / TEX_SIZE
PIXEL_Y := vec2{1, 0} / TEX_SIZE

win_size: [2]i32 = {1280, 720}



gfx_init :: proc(in_renderer: ^SDL.Renderer, in_window: ^SDL.Window) {
	
	renderer = in_renderer
	window = in_window
	SDL.SetRenderVSync(renderer, 1)

	ui.text_engine = TTF.CreateRendererTextEngine(renderer)

	gfx.renderer = renderer
	gfx.init()
}

helper_uv :: gfx.helper_uv

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

	ui.debugger_draw()

	if len(draw_state_stack) != 0 {
		log.warn("Draw State Stack should be empty when presenting.")
	}

	last_error := SDL.GetError()
	if last_error != nil {
		data := ([^]byte) ( rawptr(last_error))
		if data[0] != 0 {
			log.error(last_error)
		}
		
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
	topleft: vec2,
	botright: vec2,
}

View_Mode_Basis :: struct {
	centerpoint: vec2,
	right: vec2,
	up: vec2,
}

View_Mode :: union {
	View_Mode_Rect,
	View_Mode_Basis,
}

draw_set_view_rect :: proc(view_topleft: vec2, view_botright: vec2, scaling: View_Scaling = .Stretch) {
	draw_state.view_mode = View_Mode_Rect{scaling, view_topleft, view_botright}
	update_matrix()
}

// absolute projection, vectors are interpreted as pixels:
// so {100, 20) would make a unit be displaced that amount in pixels
draw_set_view_basis :: proc(right: vec2, up: vec2, centerpoint: vec2) {
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

			draw_pos := vec2{f32(draw_rect[0].x), f32(draw_rect[0].y)}
			draw_state.mat_scale = vec2{f32(draw_size.x), f32(draw_size.y)} / view_range
			draw_state.mat_offset = draw_pos - (view_topleft * draw_state.mat_scale)

			draw_matrix = (matrix[3, 3]f32{
						draw_state.mat_scale.x, 0, draw_state.mat_offset.x,
						0, draw_state.mat_scale.y, draw_state.mat_offset.y,
						0, 0, 1,
					})

			draw_matrix = draw_matrix * draw_state.user_matrix
			gfx.draw_matrix = draw_matrix

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
			gfx.draw_matrix = draw_matrix
	}
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
		gfx.helper, // texture
		&buffer.vertices[0][0],
		8, // verts + stride
		&fcolor,
		0, // color + stride
		&buffer.uvs[0][0],
		8, // uvs
		buffer.num_vertices,
		indices,
		buffer.num_indices,
		1,
	)
}

vertices_buf: [1000]vec2
uvs_buf: [1000]vec2
indices_buf: [2000]u8
buffer := DrawBuffer{0, 0, vertices_buf[:], uvs_buf[:], nil, indices_buf[:]}

CornerRadii :: gfx.CornerRadii
BorderWidths :: gfx.BorderWidths
Color :: m.Color

txv :: gfx.txv


draw_box_filled :: proc(box: Rect, corners: CornerRadii, color: Color) {

	num_vertices: i32 = 0
	num_indices: i32 = 0

	//corners := rect.cornerRadius

	// center full rect
	PAD :: 1 // expand for antialiasing

	//HALF_PIXEL :: vec2{0.5, 0.5}
	boxmin := vec2{box.x, box.y}
	boxmax := vec2{box.x + box.w, box.y + box.h}

	topleft := vec2{boxmin.x + corners.nw, boxmin.y + corners.nw}
	topright := vec2{boxmax.x - corners.ne, boxmin.y + corners.ne}
	botleft := vec2{boxmin.x + corners.sw, boxmax.y - corners.sw}
	botright := vec2{boxmax.x - corners.se, boxmax.y - corners.se}

	vertices_buf[0] = txv(topleft)
	vertices_buf[1] = txv(topright)
	vertices_buf[2] = txv(botleft)
	vertices_buf[3] = txv(botright)

	//	uv_center := ZERO_PIX_CLAMP + (PIXEL_Y * (width+1) * 0.5)
	uv_outer := ZERO_PIX_CLAMP + (PIXEL_Y * (0.5 - PAD))
	//	log.info(uv_outer)

	uvs_buf[0] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.nw + 0.5))
	uvs_buf[1] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.ne + 0.5))
	uvs_buf[2] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.sw + 0.5))
	uvs_buf[3] = ZERO_PIX_CLAMP + (PIXEL_Y * (corners.se + 0.5))


	indices_buf[0] = 0
	indices_buf[1] = 1
	indices_buf[2] = 2
	indices_buf[3] = 1
	indices_buf[4] = 2
	indices_buf[5] = 3

	// top bottom left right rectangles

	vertices_buf[4] = txv({topleft.x, boxmin.y - PAD})
	vertices_buf[5] = txv({topright.x, boxmin.y - PAD})

	vertices_buf[6] = txv({botleft.x, boxmax.y + PAD})
	vertices_buf[7] = txv({botright.x, boxmax.y + PAD})

	vertices_buf[8] = txv({boxmin.x - PAD, topleft.y})
	vertices_buf[9] = txv({boxmin.x - PAD, botleft.y})

	vertices_buf[10] = txv({boxmax.x + PAD, topright.y})
	vertices_buf[11] = txv({boxmax.x + PAD, botright.y})

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

	draw_rounded_corner(
		vertices_buf[:],
		indices_buf[:],
		uvs_buf[:],
		&num_vertices,
		&num_indices,
		0,
		8,
		4,
	)
	draw_rounded_corner(
		vertices_buf[:],
		indices_buf[:],
		uvs_buf[:],
		&num_vertices,
		&num_indices,
		1,
		5,
		10,
	)
	draw_rounded_corner(
		vertices_buf[:],
		indices_buf[:],
		uvs_buf[:],
		&num_vertices,
		&num_indices,
		3,
		11,
		7,
	)
	draw_rounded_corner(
		vertices_buf[:],
		indices_buf[:],
		uvs_buf[:],
		&num_vertices,
		&num_indices,
		2,
		6,
		9,
	)

	//num_vertices = i32(start_vert)
	//num_indices = start_idx + 12

	// submit
	rect_color := color
	rect_color *= draw_state.modulate
	fcolor := SDL.FColor(rect_color)

	SDL.SetRenderTextureAddressMode(renderer, .CLAMP, .CLAMP)
	SDL.SetRenderDrawBlendMode(renderer, {.BLEND})

	SDL.RenderGeometryRaw(
		renderer,
		gfx.helper, // texture
		&vertices_buf[0][0],
		8, // verts, stride
		&fcolor,
		0, // color, stride
		&uvs_buf[0][0],
		8, // uvs
		num_vertices,
		&indices_buf,
		num_indices,
		1,
	)

}


draw_rounded_corner :: proc(
	vertices_buf: []vec2,
	indices_buf: []u8,
	uvs_buf: []vec2,
	ptr_num_vertices: ^i32,
	ptr_num_indices: ^i32,
	pivot_idx: u8,
	left_idx: u8,
	right_idx: u8,
) {

	origin := vertices_buf[pivot_idx]
	start_pos := vertices_buf[left_idx] - origin

	border_uv := uvs_buf[left_idx]

	num_vertices := ptr_num_vertices^
	num_indices := ptr_num_indices^

	segments: u8
	radius: f32 = math.abs(start_pos.x) + math.abs(start_pos.y)

	segments = u8(math.min(127, math.floor(radius / math.ln(radius * 1.6 + 1))))
	if segments < 2 {
		segments = 2
	}
	//log.info("segments", segments)
	delta_angle := (math.TAU / 4) / f32(segments)
	mat_cos := math.cos(delta_angle)
	mat_sin := math.sin(delta_angle)

	start_vert := u8(num_vertices)

	vert_pos := start_pos

	//log.info(draw_state.user_matrix)
	//log.info(vert, vert3)

	for _ in 1 ..< segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vert := origin + vert_pos
		vert3 := [3]f32{vert.x, vert.y, 1}
		vert3 = draw_state.user_matrix * vert3
		vertices_buf[num_vertices] = vert //vert3.xy
		uvs_buf[num_vertices] = border_uv
		num_vertices += 1
	}

	indices_buf[num_indices] = pivot_idx
	indices_buf[num_indices + 1] = left_idx
	indices_buf[num_indices + 2] = start_vert
	num_indices += 3

	for segment in 2 ..< segments {

		indices_buf[num_indices] = pivot_idx
		indices_buf[num_indices + 1] = start_vert + segment - 2
		indices_buf[num_indices + 2] = start_vert + segment - 1
		num_indices += 3
	}

	indices_buf[num_indices] = pivot_idx
	indices_buf[num_indices + 1] = start_vert + segments - 2
	indices_buf[num_indices + 2] = right_idx
	num_indices += 3

	ptr_num_vertices^ = num_vertices
	ptr_num_indices^ = num_indices

}


draw_box_border :: proc(box: Rect, corners: CornerRadii, borders: BorderWidths, in_color: Color) {

	buffer.num_vertices = 0
	buffer.num_indices = 0

	// top
	buffer.vertices[0] = txv({box.x + corners.nw, box.y})
	buffer.vertices[1] = txv({box.x + box.w - corners.ne, box.y})
	buffer.vertices[2] = txv({box.x + corners.nw, box.y + borders.n})
	buffer.vertices[3] = txv({box.x + box.w - corners.ne, box.y + borders.n})

	end_y1 := box.y + box.h
	end_y2 := end_y1 - borders.s

	// bottom
	buffer.vertices[4] = txv({box.x + corners.sw, end_y1})
	buffer.vertices[5] = txv({box.x + box.w - corners.se, end_y1})
	buffer.vertices[6] = txv({box.x + corners.sw, end_y2})
	buffer.vertices[7] = txv({box.x + box.w - corners.se, end_y2})

	// left
	x1 := box.x
	x2 := x1 + borders.w
	y1 := box.y + corners.nw
	y2 := box.y + box.h - corners.sw
	buffer.vertices[8] = txv({x1, y1})
	buffer.vertices[9] = txv({x2, y1})
	buffer.vertices[10] = txv({x1, y2})
	buffer.vertices[11] = txv({x2, y2})

	x1 = box.x + box.w
	x2 = x1 - borders.e
	y1 = box.y + corners.ne
	y2 = box.y + box.h - corners.se
	buffer.vertices[12] = txv({x1, y1})
	buffer.vertices[13] = txv({x2, y1})
	buffer.vertices[14] = txv({x1, y2})
	buffer.vertices[15] = txv({x2, y2})

	buffer.num_vertices += 16

	for idx in 0 ..< 16 {
		buffer.uvs[idx] = {0.75, 0.75}
	}

	for idx_long in 0 ..< 4 {
		idx := u8(idx_long)
		buffer.indices[0 + (idx * 6)] = 0 + (idx * 4)
		buffer.indices[1 + (idx * 6)] = 1 + (idx * 4)
		buffer.indices[2 + (idx * 6)] = 2 + (idx * 4)
		buffer.indices[3 + (idx * 6)] = 1 + (idx * 4)
		buffer.indices[4 + (idx * 6)] = 2 + (idx * 4)
		buffer.indices[5 + (idx * 6)] = 3 + (idx * 4)
	}


	buffer.num_indices += 24


	if corners.nw != 0 {
		draw_rounded_border(&buffer, borders.n, borders.w, corners.nw, 0, {box.x, box.y})
	}
	if corners.ne != 0 {
		draw_rounded_border(&buffer, borders.n, borders.e, corners.ne, 1, {box.x + box.w, box.y})
	}
	if corners.sw != 0 {
		draw_rounded_border(&buffer, borders.s, borders.w, corners.sw, 2, {box.x, box.y + box.h})
	}
	if corners.se != 0 {
		draw_rounded_border(
			&buffer,
			borders.s,
			borders.e,
			corners.se,
			3,
			{box.x + box.w, box.y + box.h},
		)
	}

	color := in_color * draw_state.modulate
	fcolor := SDL.FColor(color)
	SDL.RenderGeometryRaw(
		renderer,
		gfx.helper, // texture
		&buffer.vertices[0][0],
		8, // verts + stride
		&fcolor,
		0, // color + stride
		&buffer.uvs[0][0],
		8, // uvs
		buffer.num_vertices,
		&buffer.indices[0],
		buffer.num_indices,
		1,
	)
}


// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
draw_rounded_border :: proc(
	buffer: ^gfx.DrawBuffer,
	width_h: f32,
	width_v: f32,
	radius: f32,
	corner_idx: int,
	corner: vec2,
) {
	segments := u8(math.min(24, math.floor(radius / math.ln(radius * 1.6 + 1))))
	vertices_buf := buffer.vertices[buffer.num_vertices:]
	uvs_buf := buffer.uvs[buffer.num_vertices:]
	indices_buf := buffer.indices[buffer.num_indices:]

	num_vertices: i32 = i32(segments) * 2 + 2
	num_indices: i32 = i32(segments) * 6
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
	v_radius_inner := flip * vec2{radius - width_v - PAD, radius - width_h - PAD}

	// draw from centerpoint +- x to centerpoint +- y
	STROKE_OFFSET :: 0
	STROKE_CONTRAST :: 1.4 // a way to compensate for gamma-blended lines,
	base := vec2{0.5, 0.5} / TEX_SIZE + STROKE_OFFSET


	uv_outer: f32 = (0.5 - PAD) * STROKE_CONTRAST

	uv_innerh: f32 = (width_h + PAD + 0.5) * STROKE_CONTRAST
	uv_innerv: f32 = (width_v + PAD + 0.5) * STROKE_CONTRAST

	uvs_buf[0] = base + ({uv_outer, uv_innerv} / TEX_SIZE)
	uvs_buf[1] = base + ({uv_innerv, uv_outer} / TEX_SIZE)

	vertices_buf[0] = txv({centerpoint.x + v_radius.x, centerpoint.y})
	vertices_buf[1] = txv(
		{centerpoint.x + v_radius_inner.x, keep_y ? corner.y + width_h : centerpoint.y},
	)
	increment := math.TAU / 4 / f32(segments)
	mat_cos := math.cos(increment)
	mat_sin := math.sin(increment)

	vert_pos := vec2{1, 0}
	for idx in 1 ..< segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx * 2] = txv(centerpoint + (vert_pos * v_radius))
		vertices_buf[idx * 2 + 1] = txv(
			centerpoint +
			([2]f32{keep_x ? 1.0 : vert_pos.x, keep_y ? 1.0 : vert_pos.y} * v_radius_inner),
		)
		uvs_buf[idx * 2] =
			base +
			({
						uv_outer,
						uv_innerv * vert_pos.x * vert_pos.x + uv_innerh * vert_pos.y * vert_pos.y,
					} /
					TEX_SIZE)
		uvs_buf[idx * 2 + 1] =
			base +
			({
						uv_innerv * vert_pos.x * vert_pos.x + uv_innerh * vert_pos.y * vert_pos.y,
						uv_outer,
					} /
					TEX_SIZE)
	}
	vertices_buf[segments * 2] = txv({centerpoint.x, centerpoint.y + v_radius.y})
	vertices_buf[segments * 2 + 1] = txv(
		{keep_x ? corner.x + width_v : centerpoint.x, centerpoint.y + v_radius_inner.y},
	)

	uvs_buf[segments * 2] = base + ({uv_outer, uv_innerh} / TEX_SIZE)
	uvs_buf[segments * 2 + 1] = base + ({uv_innerh, uv_outer} / TEX_SIZE)


	for idx_wide in 0 ..< segments {
		idx := u8(idx_wide)
		indices_buf[idx * 6] = start_index + idx * 2
		indices_buf[idx * 6 + 1] = start_index + idx * 2 + 1
		indices_buf[idx * 6 + 2] = start_index + idx * 2 + 2
		indices_buf[idx * 6 + 3] = start_index + idx * 2 + 2
		indices_buf[idx * 6 + 4] = start_index + idx * 2 + 1
		indices_buf[idx * 6 + 5] = start_index + idx * 2 + 3
	}
}
