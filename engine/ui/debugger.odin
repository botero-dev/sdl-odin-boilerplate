package ui

import "base:runtime"
import "engine:ui"
import "core:log"
import "core:mem"
import "core:fmt"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import "../gfx"
import abm "../math"

debugger_draw :: proc() {
	// if showing debugger, make ui to represent layout
	UI_DEBUGGER :: true
	if UI_DEBUGGER {
		
		base_layout_state := layout_state
		target_layout_state = base_layout_state
		
		layout_state = debug_layout_state
		
		_layout_debugger();

		layout_draw()

		debug_layout_state = layout_state

		layout_state = base_layout_state

	}
}


debug_layout_state: LayoutState
target_layout_state: LayoutState

// TODO: maybe pass layout_state as param?
_layout_debugger :: proc() {

	layout_begin({800, 600}, 1)
	defer layout_end()

	container_vertical() // full debugger view
	{
		// tree view
		layout_linear_child({height = Sizing{type = .Weight, amount = 1}})
		container_vertical()
		layout_debugger_list()
	}

	{
		// details view
		layout_linear_child({height = Sizing{type = .Weight, amount = 1}})
		container_vertical()
		// for field in selected node:
		//     show field data...
	}
}

debug_list_idx: int = 0
debug_list_depth: int = 0
layout_debugger_list :: proc() {
	debug_list_depth = 0
	debug_list_idx = 0
	layout_debugger_node()
}

layout_debugger_node :: proc() {
	idx := debug_list_idx
	debug_list_idx += 1
	decl := target_layout_state.items_decl[idx]
	num_children := decl.num_children

	layout_debugger_row(idx)
	debug_list_depth += 1
	for child_idx in 0..<num_children  {
		layout_debugger_node()
	}
	debug_list_depth -= 1
}

layout_debugger_row :: proc(idx: int) {
	decl := target_layout_state.items_decl[idx]
	computed := target_layout_state.items_tree[idx]
	description := fmt.tprint(decl.children_layout)
	container_horizontal(offsets = BoxOffsets{left = f32(20 * debug_list_depth)})
	c := Color32{full=0xFFFFFFFF}
	hovered := abm.point_in_rect(coords, computed.layout_rect)
				
	if hovered {
		c = Color32{channels={255, 255, 0, 255}}
	}
	
	layout_text(description, color = c)
}



indent: int = 0
print_layout_result :: proc() {
	if indent == 0 {
		fmt.println()
		fmt.println()
		fmt.println()
	}
	item_base := layout_state.items_decl[layout_cursor]
	item_result := layout_state.items_tree[layout_cursor]
	for idx in 0..<indent {
		fmt.print(" | ")
	}
	fmt.print(" +-")

	if len(item_base.comment) != 0 {
		fmt.printf("(%s) ", item_base.comment)
	}

	fmt.println(item_base)
	for idx in 0..<indent {
		fmt.print(" | ")
	}
	fmt.print(" | ")
	fmt.println(item_result)
	layout_cursor += 1
	indent += 1
	for idx in 0..<item_base.num_children {
		print_layout_result()
	}
	indent -= 1
}
