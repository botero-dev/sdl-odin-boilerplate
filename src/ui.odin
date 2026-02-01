
package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:c"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import clay "clay-odin"

vec2 :: [2]f32



dpi := f32(1.0)
DPI_set :: proc(new_dpi: f32) {
	dpi = new_dpi
}

border_policy :: proc (border: $T) -> u16 {
	return u16(math.round(f32(border) * dpi)) // could also be ceil or floor
}

DPI_ElementDeclaration :: proc (decl: clay.ElementDeclaration) -> clay.ElementDeclaration {
	result := decl
	result.cornerRadius = DPI_CornerRadius(decl.cornerRadius)
	result.border.width = DPI_BorderWidth(result.border.width)
	result.layout.padding = DPI_Padding(result.layout.padding)
	result.layout.childGap = border_policy(result.layout.childGap)
	if result.layout.sizing.width.type == .Fixed {
		result.layout.sizing.width.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.width.constraints.sizeMinMax.max *= dpi
	}
	if result.layout.sizing.height.type == .Fixed {
		result.layout.sizing.height.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.height.constraints.sizeMinMax.max *= dpi
	}

	return result
}

DPI :: DPI_ElementDeclaration

DPI_BorderWidth :: proc (input: clay.BorderWidth) -> clay.BorderWidth {
	return clay.BorderWidth {
		border_policy(input.left),
		border_policy(input.right),
		border_policy(input.top),
		border_policy(input.bottom),
		border_policy(input.betweenChildren),
	}
}

DPI_CornerRadius :: proc (radii: clay.CornerRadius) -> clay.CornerRadius {
	return clay.CornerRadius {
		dpi * (radii.topLeft),
		dpi * (radii.topRight),
		dpi * (radii.bottomLeft),
		dpi * (radii.bottomRight),
	}
}

DPI_Padding :: proc (padding: clay.Padding) -> clay.Padding {
	return clay.Padding {
		border_policy(padding.left),
		border_policy(padding.right),
		border_policy(padding.top),
		border_policy(padding.bottom),
	}
}

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

			text := get_text_with_font_size(text_data.fontId, text_data.fontSize)

			if text != nil {
				TTF.SetTextColor(text, u8(color[0]*255), u8(color[1]*255), u8(color[2]*255), u8(color[3]*255))
                string_slice := text_data.stringContents
                TTF.SetTextString(text, cstring(string_slice.chars), uint(string_slice.length))
                TTF.SetTextWrapWidth(text, 0)
                TTF.DrawRendererText(text, math.round(box.x), math.round(box.y))
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


FontData :: struct {
	font_io: ^SDL.IOStream,
	sizes: map[u16]^TTF.Font,
}

loaded_fonts: u16 = 1 // we reserve fontid=0 for null font
fonts: [dynamic]FontData

load_font_io :: proc(io: ^SDL.IOStream) -> u16 {
	if fonts == nil {
		append(&fonts, FontData{})
	}
	new_font := FontData {
		font_io = io
	}
	loaded_font_id := loaded_fonts
	log.info("set font io:", loaded_font_id)
	append(&fonts, new_font)
	loaded_fonts += 1
	return loaded_font_id
}

// TextElementConfig :: struct {
// 	userData:           rawptr,
// 	textColor:          Color,
// 	fontId:             u16,
// 	fontSize:           u16,
// 	letterSpacing:      u16,
// 	lineHeight:         u16,
// 	wrapMode:           TextWrapMode,
// 	textAlignment:      TextAlignment,
// }

// StringSlice :: struct {
// 	length: c.int32_t,
// 	chars:  [^]c.char,
// 	baseChars:  [^]c.char,
// }


clay_measure_text :: proc "c" (
    text: clay.StringSlice,
    config: ^clay.TextElementConfig,
    userData: rawptr,
) -> clay.Dimensions {
	context = ctx
	font := get_font_with_size(config.fontId, config.fontSize)
	if font == nil {
		log.info("unable to calculate font size")
		return {}
	}
	size := [2]c.int{}
	success := TTF.GetStringSize(font, cstring(text.chars), uint(text.length), &size.x, &size.y)
    return {
        width = f32(size.x),
        height = f32(size.y),
    }
}

get_font_with_size :: proc(font_id: u16, size: u16) -> ^TTF.Font {
	if font_id == 0 {
		return nil
	}
	font := &fonts[font_id]
	font_size, ok := font.sizes[size]
	if !ok {
		font_size = TTF.OpenFontIO(font.font_io, false, f32(size))
		font.sizes[size] = font_size
	}
	return font_size
}


// single text object gets reused
single_text: ^TTF.Text

get_text_with_font_size :: proc(font_id: u16, size: u16) -> ^TTF.Text {
	//log.info("get_text_with_size")
	font := get_font_with_size(font_id, size)
	if font == nil {
		return nil
	}
	if single_text == nil {
		single_text = TTF.CreateText(engine, font, "My Text", 0)
	}
	TTF.SetTextFont(single_text, font)
	return single_text
}



draw_box_filled :: proc (box: clay.BoundingBox, rect: clay.RectangleRenderData) {

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

    SDL.SetRenderDrawColor(renderer, u8(color[0] * 255), u8(color[1] * 255), u8(color[2] * 255), u8(color[3] * 255))
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
