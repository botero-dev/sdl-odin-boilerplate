package ui

import "../gfx"

RenderCommand :: struct {
	rect: Rect,
	// resolved while drawing, so a callback can decide per frame
	hovered:     bool,
	focused:     bool,
	state:       ModifierState,
}
/*
	layout: LayoutState,
	index: int,
	state: ModifierState,
*/

ModifierState :: enum {
	Begin,
	End,
}

ModifierContext :: struct {
	rect: Rect,
	state: ModifierState,
	hovered:     bool,
	focused:     bool,
}

// A modifier draws around the item it is attached to: it is called with .Begin
// before the item is drawn and with .End after its subtree, so it has to reach the
// same conclusion at both.
Modifier :: struct {
	callback:  proc(data: rawptr, render_command: ^ModifierContext),
	data:      rawptr,
}


modifier_wrap :: proc($func: #type proc(data: ^$T, render_command: ^ModifierContext)) -> proc(data: rawptr, render_command: ^ModifierContext) {
	_modifier_proc :: proc(data: rawptr, render_command: ^ModifierContext) {
		casted := (^T)(data)
		func(casted, render_command)
	}
	return _modifier_proc
}


modifier_custom_box :: proc(data: $T, $callback: #type proc(data: ^T, render_command: ^ModifierContext)) -> Modifier {
	ptr := new(T, context.temp_allocator)
	ptr^ = data
	modifier := Modifier {}
	modifier.callback = modifier_wrap(callback)
	modifier.data = ptr
	return modifier
}

// Fades the item and everything inside it.
modifier_modulate :: proc(color: [4]f32) -> Modifier {
	return modifier_custom_box(color, modulate_apply)
}

modulate_apply :: proc(color: ^[4]f32, render_command: ^ModifierContext) {
	switch render_command.state {
		case .Begin:
			gfx.draw_push_state()
			gfx.draw_state.modulate *= color^
		case .End:
			gfx.draw_pop_state()
	}
}

// Payload of modifier_transform, and of any custom modifier that transforms.
TransformModifier :: struct {
	mat:   matrix[3, 3]f32,
	pivot: f32x2,
}


// receives a modifier, returns a function that applies that modifier to a render command
modifier_transform :: proc(tx_mod: TransformModifier) -> Modifier {
	return modifier_custom_box(tx_mod, transform_apply)
}

transform_apply :: proc(data: ^TransformModifier, render_command: ^ModifierContext) {
	if render_command.state == .End {
		gfx.draw_pop_state()
		return
	}

	gfx.draw_push_state()

	box := render_command.rect

	mat: matrix[3, 3]f32 = 1
	pivot_abs := [3]f32 {
		box.x + (box.w * data.pivot.x),
		box.y + (box.h * data.pivot.y),
		0,
	}

	pivot_mat: matrix[3, 3]f32 = 1
	pivot_mat[2] = -pivot_abs
	pivot_mat[2][2] = 1

	mat *= pivot_mat
	mat = data.mat * mat

	pivot_mat[2] = pivot_abs
	pivot_mat[2][2] = 1

	mat = pivot_mat * mat

	gfx.draw_set_matrix(mat)
}
