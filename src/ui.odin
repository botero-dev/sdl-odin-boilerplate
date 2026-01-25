
package main

import "core:fmt"
import "core:log"
import "core:math"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import clay "clay-odin"

vec2 :: [2]f32

render_layout :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for idx in 0..<i32(render_commands.length) {
        render_command := clay.RenderCommandArray_Get(render_commands, idx)
        #partial switch render_command.commandType {
        case .Rectangle:
            rect := render_command.renderData.rectangle
			box := render_command.boundingBox
			corners := rect.cornerRadius
			if corners == {0, 0, 0, 0} {
				//fmt.println(render_command)
				color := rect.backgroundColor
				SDL.SetRenderDrawColor(renderer, u8(color[0] * 255), u8(color[1] * 255), u8(color[2] * 255), u8(color[3]) * 255)
				SDL.SetRenderDrawBlendMode(renderer, {.BLEND})
				rect2 := SDL.FRect{
					w = box.width,
					h = box.height,
					x = box.x,
					y = box.y,
				}
				SDL.RenderFillRect(renderer, &rect2)
			} else {
				draw_box_filled(box, rect)
			}


		case .Border:

			border := render_command.renderData.border
            draw_box_border(render_command.boundingBox, border)


		case .Text:
            //fmt.println(render_command)
            box := render_command.boundingBox
            text_data := render_command.renderData.text
            color := text_data.textColor

			text = get_text_with_font_size(int(text_data.fontSize))

			if text != nil {
			    TTF.SetTextColor(text, u8(color[0]*255), u8(color[1]*255), u8(color[2]*255), u8(color[3]*255))
                string_slice := text_data.stringContents
                TTF.SetTextString(text, cstring(string_slice.chars), uint(string_slice.length))
                TTF.SetTextWrapWidth(text, 0)
                TTF.DrawRendererText(text, box.x, box.y)
            }

		case .Image:

			image := render_command.renderData.image
            color := image.backgroundColor

			tex := (^SDL.Texture)(image.imageData)
            SDL.SetTextureColorMod(tex, u8(color[0]), u8(color[1]), u8(color[2]))
			SDL.SetTextureAlphaMod(tex, u8(color[3]))
			SDL.SetTextureBlendMode(tex, {.BLEND})

            box := render_command.boundingBox
            rect2 := SDL.FRect{
                w = box.width,
                h = box.height,
                x = box.x,
                y = box.y,
            }
            SDL.RenderTexture(renderer, tex, nil, &rect2)

			corners := image.cornerRadius
			if corners != {0, 0, 0, 0} {
				log.info("image unhandled case!")
			}


        case:
        	// hello
        	fmt.println("unhandled render command type:", render_command.commandType, render_command)
        }

    }
}


font_io: ^SDL.IOStream
fonts: map[int]^TTF.Font
text: ^TTF.Text

set_font_io :: proc(io: ^SDL.IOStream) {
	font_io = io
	log.info("set font io")
}

get_font_with_size :: proc(size: int) -> ^TTF.Font {
	font, ok := fonts[size]
	if !ok {
		if font_io == nil {
			return nil
		}
		font = TTF.OpenFontIO(font_io, false, f32(size))
		fonts[size] = font
	}

    if font == nil {
        fmt.println("unable to load font:", SDL.GetError())
    }
	return font
}

get_text_with_font_size :: proc(size: int) -> ^TTF.Text {
	//log.info("get_text_with_size")
	font := get_font_with_size(size)
	if font == nil {
		return nil
	}
	if text == nil {
		text = TTF.CreateText(engine, font, "My Text", 0)
		TTF.SetTextColor(text, 255, 255, 255, 255)
	}
	else {
		TTF.SetTextFont(text, font)
	}
	return text
}



draw_box_filled :: proc (box: clay.BoundingBox, rect: clay.RectangleRenderData) {

	vertices_buf: [1000]vec2
	indices_buf: [2000]u8

	num_vertices: i32 = 0
	num_indices: i32 = 0

	corners := rect.cornerRadius

	// center full rect
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

	indices_buf[0] = 0
	indices_buf[1] = 1
	indices_buf[2] = 2
	indices_buf[3] = 1
	indices_buf[4] = 2
	indices_buf[5] = 3

	// top bottom left right rectangles

	vertices_buf[4] = {topleft.x,  boxmin.y}
	vertices_buf[5] = {topright.x, boxmin.y}

	vertices_buf[6] = {botleft.x,  boxmax.y}
	vertices_buf[7] = {botright.x, boxmax.y}

	vertices_buf[8] = {boxmin.x,  topleft.y}
	vertices_buf[9] = {boxmin.x,  botleft.y}

	vertices_buf[10] = {boxmax.x,  topright.y}
	vertices_buf[11] = {boxmax.x,  botright.y}

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

	draw_rounded_corner(vertices_buf[:], indices_buf[:], &num_vertices, &num_indices,0, 8, 4,  { -corners.topLeft, 0 }, topleft)
	draw_rounded_corner(vertices_buf[:], indices_buf[:], &num_vertices, &num_indices,1, 5, 10, { 0, -corners.topRight }, topright)
	draw_rounded_corner(vertices_buf[:], indices_buf[:], &num_vertices, &num_indices,3, 11, 7, { corners.bottomRight, 0 }, botright)
	draw_rounded_corner(vertices_buf[:], indices_buf[:], &num_vertices, &num_indices,2, 6, 9,  { 0, corners.bottomLeft }, botleft)

	//num_vertices = i32(start_vert)
	//num_indices = start_idx + 12

	// submit
	fcolor := SDL.FColor(rect.backgroundColor)

	SDL.RenderGeometryRaw(
		renderer,
		nil, // texture
		&vertices_buf[0][0], 8, // verts, stride
		&fcolor, 0, // color, stride
		nil, 0, // uvs
		num_vertices,
		&indices_buf, num_indices, 1
	)

}


draw_rounded_corner :: proc (
	vertices_buf: []vec2, indices_buf: []u8,
	ptr_num_vertices: ^i32, ptr_num_indices: ^i32,
	pivot_idx: u8, left_idx: u8, right_idx: u8,
	start_pos: vec2, origin: vec2) {

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

	color := border.color
	borderwidth := border.width
	corners := border.cornerRadius
	rect := box

    SDL.SetRenderDrawColor(renderer, u8(color[0] * 255), u8(color[1] * 255), u8(color[2] * 255), u8(color[3] * 255))
	SDL.SetRenderDrawBlendMode(renderer, {.BLEND})

    rect2: SDL.FRect

	// top border
	rect2.y = box.y
	rect2.h = f32(borderwidth.top)
	rect2.x = box.x + corners.topLeft
	rect2.w = box.width - corners.topLeft - corners.topRight
	SDL.RenderFillRect(renderer, &rect2)

	// bottom border
	rect2.y = box.y + box.height - f32(borderwidth.bottom)
	rect2.h = f32(borderwidth.bottom)
	rect2.x = box.x + corners.bottomLeft
	rect2.w = box.width - corners.bottomLeft - corners.bottomRight
	SDL.RenderFillRect(renderer, &rect2)

	// left border
	rect2.y = box.y + corners.topLeft
	rect2.h = box.height - corners.topLeft - corners.bottomLeft
	rect2.w = f32(borderwidth.left)
	rect2.x = box.x
	SDL.RenderFillRect(renderer, &rect2)

	// right border
	rect2.y = box.y + corners.topRight
	rect2.h = box.height - corners.topRight - corners.bottomRight
	rect2.x = box.x + box.width - f32(borderwidth.right)
	rect2.w = f32(borderwidth.right)
    SDL.RenderFillRect(renderer, &rect2)

	segments :: 4 // maybe calculate based on perimeter and pixel precision?
	angle: f32 = math.TAU / 2

	fcolor := SDL.FColor(color)

	if corners.topLeft != 0 {
		draw_rounded_border(renderer, fcolor, f32(borderwidth.top), f32(borderwidth.left), corners.topLeft, 0, {box.x, box.y})
	}
	if corners.topRight != 0 {
		draw_rounded_border(renderer, fcolor, f32(borderwidth.top), f32(borderwidth.right), corners.topRight, 1, {box.x+box.width, box.y})
	}
	if corners.bottomLeft != 0 {
		draw_rounded_border(renderer, fcolor, f32(borderwidth.bottom), f32(borderwidth.left), corners.bottomLeft, 2, {box.x, box.y+box.height})
	}
	if corners.bottomRight != 0 {
		draw_rounded_border(renderer, fcolor, f32(borderwidth.bottom), f32(borderwidth.right), corners.bottomRight, 3, {box.x+box.width, box.y+box.height})
	}
}


// corner_idx indices: (top_left, top_right, bottom_left, bottom_right)
draw_rounded_border :: proc (renderer: ^SDL.Renderer, color: SDL.FColor, width_h: f32, width_v: f32, radius: f32, corner_idx: int, corner: vec2) {
	segments  := u8(math.min(127, math.floor(radius/math.ln(radius*1.6+1))))
	num_vertices : i32 = i32(segments) * 2 + 2
	num_indices : i32 = i32(segments) * 6
	vertices_buf: [1000]vec2
	indices_buf: [2000]u8

	// keeping it as vec makes some stuff easier
	v_radius := vec2 {radius, radius}
	v_radius_inner := v_radius - vec2{width_v, width_h}

	keep_x := width_v > radius
	keep_y := width_h > radius

	// corners 0 and 2 are in the left, so centerpoint is to the right
	if corner_idx % 2 == 0 {
		v_radius.x *= -1
		v_radius_inner.x *= -1
	}

	// corners 0 and 1 are in the top, so centerpoint is below
	if corner_idx & 2 == 0 {
		v_radius.y *= -1
		v_radius_inner.y *= -1
	}
	centerpoint := corner - v_radius

	// draw from centerpoint +- x to centerpoint +- y
	vertices_buf[0] = { corner.x,                         centerpoint.y }
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
	}
	vertices_buf[segments*2] =   { centerpoint.x, corner.y }
	vertices_buf[segments*2+1] = { keep_x ? corner.x + width_v : centerpoint.x, centerpoint.y + v_radius_inner.y}

	for idx_wide in 0..<segments {
		idx := u8(idx_wide)
		indices_buf[idx * 6]     = idx * 2
		indices_buf[idx * 6 + 1] = idx * 2 + 1
		indices_buf[idx * 6 + 2] = idx * 2 + 2
		indices_buf[idx * 6 + 3] = idx * 2 + 2
		indices_buf[idx * 6 + 4] = idx * 2 + 1
		indices_buf[idx * 6 + 5] = idx * 2 + 3
	}

	fcolor := color

	SDL.RenderGeometryRaw(
		renderer,
		nil, // texture
		&vertices_buf[0][0], 8, // verts + stride
		&fcolor, 0, // color + stride
		nil, 0, // uvs
		num_vertices,
		&indices_buf, num_indices, 1
	)
}
