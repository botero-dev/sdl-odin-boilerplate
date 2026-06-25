
package engine

import "engine:ui"
import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:strings"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import clay "clay-odin"



vec2 :: [2]f32
dpi_user := f32(1)
dpi_window := f32(1)


dpi := f32(1.0)
DPI_set :: proc(new_dpi: f32) {
	dpi = new_dpi
	log.info("set dpi to:", dpi)
}

DPI_mult :: proc "contextless" (value: f32) -> f32 {
	return value * dpi
}

print_render_commands: bool


render_layout :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {

	for idx in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(render_commands, idx)

		box := transmute(Rect)render_command.boundingBox

		switch render_command.commandType {
		case .Rectangle:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.rectangle)
			}

			rect := render_command.renderData.rectangle
			corners := rect.cornerRadius
			if corners == {0, 0, 0, 0} {
				//fmt.println(render_command)
				color := rect.backgroundColor
				SDL.SetRenderDrawColorFloat(renderer, color[0], color[1], color[2], color[3])
				SDL.SetRenderDrawBlendMode(renderer, {.BLEND})
				rect2 := SDL.FRect(box)
				SDL.RenderFillRect(renderer, &rect2)
			} else {
				corners := transmute(CornerRadii)rect.cornerRadius
				color := Color(rect.backgroundColor)
				draw_box_filled(box, corners, color)
			}

		case .Border:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.border)
			}

			border := render_command.renderData.border
			radii := transmute(CornerRadii)border.cornerRadius
			borders := BorderWidths {
				f32(border.width.left),
				f32(border.width.right),
				f32(border.width.top),
				f32(border.width.bottom),
			}
			draw_box_border(box, radii, borders, border.color)

		case .Text:
			//fmt.println(render_command)
			text_data := render_command.renderData.text
			string_slice := text_data.stringContents
			color := text_data.textColor

			text := ui.get_text_with_font_size(text_data.fontId, text_data.fontSize)

			if text != nil {
				color *= draw_state.modulate
				TTF.SetTextColor(
					text,
					u8(color[0] * 255),
					u8(color[1] * 255),
					u8(color[2] * 255),
					u8(color[3] * 255),
				)
				TTF.SetTextString(text, cstring(string_slice.chars), uint(string_slice.length))
				TTF.SetTextWrapWidth(text, 0)
				//TTF.DrawRendererText(text, math.round(box.x), math.round(box.y))

				m := linalg.transpose(draw_state.user_matrix)
				TTF.DrawRendererTextTx(text, box.x, box.y, &m[0][0])
			}

		case .Image:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.image)
			}

			image := render_command.renderData.image
			color := image.backgroundColor

			tex := (^SDL.Texture)(image.imageData)
			SDL.SetTextureColorModFloat(tex, color[0], color[1], color[2])
			SDL.SetTextureAlphaModFloat(tex, color[3])
			SDL.SetTextureBlendMode(tex, {.BLEND})

			rect2 := SDL.FRect(box)
			SDL.RenderTexture(renderer, tex, nil, &rect2)

			corners := image.cornerRadius
			if corners != {0, 0, 0, 0} {
				log.info("image unhandled case!")
			}
		case .ScissorStart:
			clip_rect := SDL.Rect{i32(box.x), i32(box.y), i32(box.w), i32(box.h)}
			SDL.SetRenderClipRect(renderer, &clip_rect)
		case .ScissorEnd:
			SDL.SetRenderClipRect(renderer, nil)
		case .None:
			fmt.println(
				"unhandled render command type: None",
				render_command.commandType,
				render_command,
			)
		case .Custom:
			custom_render_data: clay.CustomRenderData = render_command.renderData.custom

			custom_data := (^CustomRenderData)(custom_render_data.customData)
			custom_data.callback(custom_data, render_command)
		}
	}
}

CustomRenderCallback :: #type proc(
	render_data: ^CustomRenderData,
	render_command: ^clay.RenderCommand,
)

CustomRenderData :: struct {
	callback: CustomRenderCallback,
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


clay_memory: []byte

ui_init :: proc() {
	ui._nav_init()

	min_size := clay.MinMemorySize()
	clay_memory = make([]byte, min_size)
	clay_arena := clay.CreateArenaWithCapacityAndMemory(uint(min_size), &clay_memory[0])
	clay.Initialize(clay_arena, {}, {handler = clay_error_handler})
	clay.SetMeasureTextFunction(ui.clay_measure_text, nil)
	clay.SetCullingEnabled(false)

	request_data_async("InterVariable.ttf", nil, assign_font)
}


assign_font :: proc(result: RequestResult) {

	bytes := result.bytes
	assert(len(bytes) != 0)
	io := SDL.IOFromConstMem(&bytes[0], len(bytes))

	default_font_id = ui.load_font_io(io)
}


default_font_id: u16 = ui.NIL_FONT



clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = get_global_context()
	log.info(errorData)
}



UIModifier :: struct {
	using custom_render_data: CustomRenderData,
	pushed:                   bool,
	wrap:                     bool,
	// wrap modifiers are added as parents of modified elements
	// while nowrap are added as siblings
}

UIModifierModulate :: struct {
	using base: UIModifier,
	color:      [4]f32,
}

ui_modifier_modulate :: proc(color: [4]f32) -> UIModifierModulate {
	return {callback = ui_modifier_modulate_callback, wrap = false, color = color}
}

ui_modifier_modulate_callback :: proc(
	render_data: ^CustomRenderData,
	render_command: ^clay.RenderCommand,
) {
	modulate := (^UIModifierModulate)(render_data)
	if !modulate.pushed {
		draw_push_state()
		draw_state.modulate *= modulate.color
		modulate.pushed = true
	} else {
		draw_pop_state()
		modulate.pushed = false
	}
}

UIModifierTransform :: struct {
	using base: UIModifier,
	mat:        matrix[3, 3]f32,
	pivot:      vec2,
}
ui_modifier_transform :: proc "contextless" (
	in_mat: matrix[3, 3]f32,
	in_pivot: vec2,
) -> UIModifierTransform {
	return {callback = ui_modifier_transform_callback, wrap = true, mat = in_mat, pivot = in_pivot}
}
ui_modifier_transform_callback :: proc(
	render_data: ^CustomRenderData,
	render_command: ^clay.RenderCommand,
) {
	modifier := (^UIModifierTransform)(render_data)
	if !modifier.pushed {
		draw_push_state()

		box := transmute(Rect)render_command.boundingBox

		mat: matrix[3, 3]f32 = 1
		pivot_abs := [3]f32 {
			box.x + (box.w * modifier.pivot.x),
			box.y + (box.h * modifier.pivot.y),
			0,
		}

		pivot_mat: matrix[3, 3]f32 = 1
		pivot_mat[2] = -pivot_abs
		pivot_mat[2][2] = 1

		mat *= pivot_mat
		mat = modifier.mat * mat

		pivot_mat[2] = pivot_abs
		pivot_mat[2][2] = 1

		mat = pivot_mat * mat

		draw_set_matrix(mat)

		modifier.pushed = true
	} else {
		draw_pop_state()
		modifier.pushed = false
	}
}

// maybe wraps draw calls that happen inside push/pop into a custom RT and then
// draws the RT to the screen
UIModifierFlatten :: struct {}


current_modifier: ^UIModifier

ui_modifier_push :: proc(modifier: ^UIModifier) {
	// only open
	ui._layout_create(ui.Layout_Extend{})
	ui.clay_elem.custom = {modifier}
	ui._layout_open()

	if !modifier.wrap {
		ui._layout_close()
	}
}

ui_modifier_pop :: proc(modifier: ^UIModifier) {
	if modifier.wrap {
		ui._layout_close()
	}
	ui._layout_create(ui.Layout_Extend{})
	ui.clay_elem.custom = {modifier}
	ui._layout_open()
	ui._layout_close()
}

@(deferred_in = ui_modifier_pop)
ui_modifier :: proc(modifier: ^UIModifier) {
	ui_modifier_push(modifier)
}
