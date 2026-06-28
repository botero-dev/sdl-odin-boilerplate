package gfx

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"


import "core:log"
import "core:math"
import "core:math/linalg"


f32x2 :: [2]f32
f32x3 :: [3]f32
f32x4 :: [4]f32

CircleShape :: struct {
    center: f32x2,
    radius: f32,
}

LineStyleSimple :: struct {
    width: f32, // how to know if line size is world-space or screen-space
    pattern: u8,
    color: f32x4 // maybe use a union with gradient?
}

LineStyle :: union {
    LineStyleSimple
}

FillStyleColor :: struct { // maybe should be a union?
    color: f32x4 // maybe allow gradient someday?
    // maybe allow for CAD hatch patterns?
}

FillStyleGradient :: struct {
    node_count: u8,
    shape: u8, // TODO: enum {linear, radial, angle, inverted flag?, wrapmode?}
    colors: [8]f32x4,
    knots: [8]f32,
    origin: f32x2,
    axis: f32x2, // used for scale and angle of gradient
}

FillStyle :: union {
    FillStyleColor,
    FillStyleGradient,
    //FillStylePattern,
    //FillStyleTexture
}

ShapeStyle :: struct {
    line: LineStyle,
    fill: FillStyle,
}


DrawBuffer :: struct {
	num_vertices: i32,
	num_indices:  i32,
	vertices:     []f32x2,
	uvs:          []f32x2,
	colors:       [][4]f32,
	indices:      []u8,
}

vertices_buf: [1000]f32x2
buffer := DrawBuffer{0, 0, vertices_buf[:], uvs_buf[:], nil, indices_buf[:]}


helper_uv :: proc(input: f32x2) -> f32x2 {return (input + 0.5) * 0.5} 	// coord + half pixel / tex_size


draw_circle_basic :: proc(
	in_center: f32x2,
	in_radius: f32,
	in_color: [4]f32 = {1, 1, 1, 1},
	int_coords: bool = false,
) {
	buffer.num_vertices = 0
	buffer.num_indices = 0
	buffer_circle(&buffer, in_center, in_radius, int_coords)
	draw_buffer(renderer, &buffer, in_color)
}

// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
buffer_circle :: proc(
	buffer: ^DrawBuffer,
	in_center: f32x2,
	in_radius: f32,
	int_coords: bool = false,
) {

	center := (draw_matrix * [3]f32{in_center.x, in_center.y, 1}).xy

	scale_mat := matrix[2, 2]f32{
		draw_matrix[0][0], draw_matrix[0][1],
		draw_matrix[1][0], draw_matrix[1][1],
	}
	radius := in_radius * linalg.length(scale_mat * [2]f32{0.7, 0.7})

	if int_coords {
		center += {0.5, 0.5}
		radius -= 0.5
	} // half pixel offset

	segments := i32(math.floor(radius * math.TAU / math.ln(radius * math.TAU * 1.6 + 1)))
	segments = math.min(124, math.max(segments, 8))
	segments = i32(math.round(f32(segments) / 4)) * 4
	vertices_buf := buffer.vertices[buffer.num_vertices:]
	uvs_buf := buffer.uvs[buffer.num_vertices:]
	indices_buf := buffer.indices[buffer.num_indices:]

	num_vertices := segments + 1
	num_indices := segments * 3

	buffer.num_vertices += num_vertices
	buffer.num_indices += num_indices


	PAD := f32(0.73) // lowest practical number, I guess the optimal thing could be sqrt(3)-1


	increment := math.TAU / f32(segments)
	mat_sin, mat_cos := math.sincos(increment)

	vert_pos := f32x2{1, 0}

	vertices_buf[0] = center
	vertices_buf[1] = center + (vert_pos * scale_mat) // TODO: account for pad
	uvs_buf[0] = helper_uv({1, 1})
	uvs_buf[1] = helper_uv({1, 0.5 - (0.5 * PAD / radius)})

	for idx in 2 ..= segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx] = center + (vert_pos * scale_mat) // TODO: account for pad
		uvs_buf[idx] = uvs_buf[1]
	}

	STRIDE :: 3
	for idx_wide in 0 ..< segments {
		idx := u8(idx_wide)
		indices_buf[idx_wide * STRIDE] = 0
		indices_buf[idx_wide * STRIDE + 1] = 1 + idx
		indices_buf[idx_wide * STRIDE + 2] = 2 + idx
	}
	indices_buf[(segments - 1) * STRIDE + 2] = 1 // last triangle end is actually first triangle begin
}


draw_line :: proc(
	renderer: ^SDL.Renderer,
	in_start: f32x2,
	in_end: f32x2,
	in_width: f32,
	in_color: [4]f32 = {1, 1, 1, 1},
) {
	buffer.num_vertices = 0
	buffer.num_indices = 0
	buffer_line(&buffer, in_start, in_end, in_width)
	draw_buffer(renderer, &buffer, in_color)
}


buffer_line :: proc(buffer: ^DrawBuffer, in_start: f32x2, in_end: f32x2, in_width: f32) {

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
	//log.info(start, starta, end, enda)

	start = starta.xy
	end = enda.xy

	if start.x == end.x { 
		start.x = math.round(start.x)
		end.x = start.x
	}
	if start.y == end.y {
		start.y = math.round(start.y)
		end.y = start.y
	}
	
	delta := end - start
	length := linalg.length(delta)
	dir := delta / length
	dir_side := f32x2{dir.y, -dir.x}

	PAD := f32(0.5)
	side := dir_side * (width * 0.5 + PAD)

	vstart := start + f32x2{0.5, 0.5} // offset to find pixel center
	vend := end + f32x2{0.5, 0.5} // offset to find pixel center

	line_offset := dir * ((0.5 + PAD))
	line_start := vstart - line_offset
	line_end := vend + line_offset

	verts := []f32x2 {
		line_start - side,
		line_start + side,
		line_end - side,
		line_end + side,
		line_end - side,
		line_start + side,
	}

	indices := []u8{0, 1, 2, 3, 4, 5}

	width_falloff := 0.5 / width
	length_falloff := 0.5 / length

	START := 0.5 - length_falloff
	END := 1.5 + length_falloff
	LEFT := 0.5 - width_falloff
	RIGHT := 1.5 + width_falloff

	uvs := []f32x2 {
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
	for idx in 0 ..< len(verts) {
		vertices_write[idx] = verts[idx]
		uvs_write[idx] = uvs[idx]
	}

	indices_write := buffer.indices[buffer.num_indices:]
	for idx in 0 ..< len(indices) {
		indices_write[idx] = indices[idx]
	}
	buffer.num_indices += i32(len(indices))
}



draw_circle :: proc(
    shape: CircleShape,
    style: ShapeStyle,
) {
    shared_buffer := &buffer

    in_color := f32x4 {1, 1, 1, 1}
    if style.fill != nil {
        shared_buffer.num_vertices = 0
        shared_buffer.num_indices = 0
        buffer_circle_fill(shared_buffer, shape.center, shape.radius)
        draw_buffer(renderer, shared_buffer, in_color)
    }
    if simpleline, simpleline_ok := style.line.(LineStyleSimple); simpleline_ok {
        shared_buffer.num_vertices = 0
        shared_buffer.num_indices = 0
        buffer_circle_outline(shared_buffer, shape.center, shape.radius, simpleline.width)
        draw_buffer(renderer, shared_buffer, in_color)
    }
}

// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
buffer_circle_outline :: proc(
	buffer: ^DrawBuffer,
	in_center: f32x2,
	in_radius: f32,
    line_width: f32
) {

    draw_matrix := draw_matrix
	center := (draw_matrix * [3]f32{in_center.x, in_center.y, 1}).xy

	scale_mat := matrix[2, 2]f32{
		draw_matrix[0][0], draw_matrix[0][1],
		draw_matrix[1][0], draw_matrix[1][1],
	}
	radius := in_radius // * linalg.length(scale_mat * [2]f32{0.7, 0.7})
    screen_radius := radius * linalg.length(scale_mat * [2]f32{0.7, 0.7})

    // figure out a reasonable number of vertices based on draw size
    // could be cached
	segments := i32(math.floor(screen_radius * math.TAU / math.ln(screen_radius * math.TAU * 1.6 + 1)))
	segments = math.min(124, math.max(segments, 8))
	segments = i32(math.round(f32(segments) / 4)) * 4

    // slice to write
	vertices_buf := buffer.vertices[buffer.num_vertices:]
	uvs_buf := buffer.uvs[buffer.num_vertices:]
	indices_buf := buffer.indices[buffer.num_indices:]

	num_vertices := segments * 2
	num_indices := segments * 6

	buffer.num_vertices += num_vertices
	buffer.num_indices += num_indices


	PAD := f32(0.73) // lowest practical number, I guess the optimal thing could be sqrt(3)-1

    
    offset := (line_width * 0.5 + PAD) * linalg.normalize(scale_mat[0]) + linalg.normalize(scale_mat[1])

	increment := math.TAU / f32(segments)
	mat_sin, mat_cos := math.sincos(increment)

	vert_pos := f32x2{1, 0}

	vertices_buf[0] = center + (vert_pos * scale_mat)
	vertices_buf[1] = center + (vert_pos * scale_mat) // TODO: account for pad
	uvs_buf[0] = helper_uv({1, 0.5 - (0.5 * PAD / line_width)})
    uvs_buf[1] = helper_uv({1, 1.5 + (0.5 * PAD / line_width)})

	for idx := i32(0); idx < num_vertices; idx += 2 {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx]   = center + (vert_pos * radius * scale_mat) - (vert_pos * offset) // TODO: account for pad
		vertices_buf[idx+1] = center + (vert_pos * radius * scale_mat) + (vert_pos * offset) // TODO: account for pad
		uvs_buf[idx] = uvs_buf[0]
		uvs_buf[idx+1] = uvs_buf[1]
	}

	STRIDE :: 6
	for segment in 0 ..< segments {
		idx := u8(segment) * 2
		indices_buf[segment * STRIDE]     = idx
		indices_buf[segment * STRIDE + 1] = idx + 1
		indices_buf[segment * STRIDE + 2] = idx + 2
		indices_buf[segment * STRIDE + 3] = idx + 1
		indices_buf[segment * STRIDE + 4] = idx + 2
		indices_buf[segment * STRIDE + 5] = idx + 3
	}

    // last segment should use indices from start of array
	indices_buf[(segments - 1) * STRIDE + 2] = 0
	indices_buf[(segments - 1) * STRIDE + 4] = 0
	indices_buf[(segments - 1) * STRIDE + 5] = 1
}

// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
buffer_circle_fill :: proc(
	buffer: ^DrawBuffer,
	in_center: f32x2,
	in_radius: f32,
	int_coords: bool = false,
) {

    center := (draw_matrix * [3]f32{in_center.x, in_center.y, 1}).xy

	scale_mat := matrix[2, 2]f32{
		draw_matrix[0][0], draw_matrix[0][1],
		draw_matrix[1][0], draw_matrix[1][1],
	}
	radius := in_radius * linalg.length(scale_mat * [2]f32{0.7, 0.7})

	if int_coords {
		center += {0.5, 0.5}
		radius -= 0.5
	} // half pixel offset

	segments := i32(math.floor(radius * math.TAU / math.ln(radius * math.TAU * 1.6 + 1)))
	segments = math.min(124, math.max(segments, 8))
	segments = i32(math.round(f32(segments) / 4)) * 4
	vertices_buf := buffer.vertices[buffer.num_vertices:]
	uvs_buf := buffer.uvs[buffer.num_vertices:]
	indices_buf := buffer.indices[buffer.num_indices:]

	num_vertices := segments + 1
	num_indices := segments * 3

	buffer.num_vertices += num_vertices
	buffer.num_indices += num_indices


	PAD := f32(0.73) // lowest practical number, I guess the optimal thing could be sqrt(3)-1


	increment := math.TAU / f32(segments)
	mat_sin, mat_cos := math.sincos(increment)

	vert_pos := f32x2{1, 0}

	vertices_buf[0] = center
	vertices_buf[1] = center + (vert_pos * scale_mat) // TODO: account for pad
	uvs_buf[0] = helper_uv({1, 1})
	uvs_buf[1] = helper_uv({1, 0.5 - (0.5 * PAD / radius)})

	for idx in 2 ..= segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		vertices_buf[idx] = center + (vert_pos * scale_mat) // TODO: account for pad
		uvs_buf[idx] = uvs_buf[1]
	}

	STRIDE :: 3
	for idx_wide in 0 ..< segments {
		idx := u8(idx_wide)
		indices_buf[idx_wide * STRIDE] = 0
		indices_buf[idx_wide * STRIDE + 1] = 1 + idx
		indices_buf[idx_wide * STRIDE + 2] = 2 + idx
	}
	indices_buf[(segments - 1) * STRIDE + 2] = 1 // last triangle end is actually first triangle begin
}
