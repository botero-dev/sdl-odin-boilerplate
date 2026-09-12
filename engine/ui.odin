
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

ui_init :: proc() {
	ui.init()

}





CustomRenderData :: struct {
	callback: proc(render_data: ^CustomRenderData, render_command: ^RenderCommand),
}
RenderCommand :: struct {
	boundingBox: Rect
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
	render_command: ^RenderCommand,
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
	render_command: ^RenderCommand,
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
	//ui.clay_elem.custom = {modifier}
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
	//ui.clay_elem.custom = {modifier}
	ui._layout_open()
	ui._layout_close()
}

@(deferred_in = ui_modifier_pop)
ui_modifier :: proc(modifier: ^UIModifier) {
	ui_modifier_push(modifier)
}
