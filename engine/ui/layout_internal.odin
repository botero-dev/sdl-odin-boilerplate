package ui

import "core:log"
import "core:strings"
import "core:mem"
import "core:fmt"

import abm "../math"


f32x2 :: [2]f32

Rect :: abm.Rect

Layout_Custom_GetFitSize :: #type proc() -> f32x2
Layout_Custom_LayoutCallback :: #type proc()
Layout_Custom_RenderCallback :: #type proc(layout: LayoutState, index: int)

Layout_Custom_Data :: struct {
	calc_fitsize: Layout_Custom_GetFitSize,
	calc_layout: Layout_Custom_LayoutCallback,
	callback_render: Layout_Custom_RenderCallback,
	user_data: rawptr,
}


current_layout_dimensions: f32x2

_layout_set_dimensions :: proc(size: f32x2) {

    current_layout_dimensions = size

}

text_round_policy := RoundingPolicy.Round
border_round_policy := RoundingPolicy.Round
padding_round_policy := RoundingPolicy.Round



_layout_set_default_config :: proc() {
}

_layout_begin :: proc(in_scale_factor: f32) {

	clear(&layout_state.items_decl)
	clear(&layout_state.items_tree)

	if layout_state.computed_mem == nil {
		layout_state.computed_mem = make([]byte, 1024*1024)
	}

	if layout_state.text_arena_mem == nil {
		layout_state.text_arena_mem = make([]byte, 1024*1024)
	}

	mem.arena_init(&layout_state.text_arena, layout_state.text_arena_mem)
	mem.arena_init(&layout_state.computed_arena, layout_state.computed_mem)

    scale_factor = in_scale_factor
	container_idx = -1
}


_layout_end :: proc() {
	_layout_compute()
}


child_layout: ChildrenLayout
container_idx: int


new_item_idx: int

_layout_create :: proc(in_child_layout: ChildrenLayout) {
	if container_idx != -1 {
		layout_state.items_decl[container_idx].num_children += 1
	}

	child_layout = in_child_layout

	new_item_idx = len(layout_state.items_decl)
	append(&layout_state.items_decl, LayoutItemDeclaration {})
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.layout_hint = layout_hint
	layout_hint = nil

	append(&layout_stack, child_layout)
}

StyleOverride :: struct {
	type: typeid,
	data: rawptr,
}

DummyType :: struct {}

_layout_open :: proc(comment: string = "") {
	dummy: ^DummyType = nil

	_layout_open_styled(comment, dummy)
}


_layout_open_styled :: proc(comment: string = "", style: ^$T = nil) {
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.children_layout = child_layout
	item_decl.parent_idx = container_idx

	if style != nil {
		when T ==  BoxStyleColored {
			box_colored := (^BoxStyleColored)(style)
			item_decl.color = box_colored.background
			item_decl.padding = box_colored.padding
			item_decl.box_style = style^ // copied, maybe we should store pointer?
			
		} else when T == ButtonStyle {
			button_style := (^ButtonStyle)(style)
			box_colored := button_style.idle_box.(BoxStyleColored)
			item_decl.color = box_colored.background
			item_decl.padding = box_colored.padding
		}
		item_decl.override = {T, style}
	} 

	item_decl.comment = comment
	
	
	container_idx = new_item_idx

	#partial switch &children_layout in item_decl.children_layout {

		case Layout_Linear_Horizontal:
			if item_decl.override.type == ContainerLinearStyle {
				children_layout.separation = ((^ContainerLinearStyle)(item_decl.override.data)).separation
			}
		case Layout_Linear_Vertical:
			if item_decl.override.type == ContainerLinearStyle {
				children_layout.separation = ((^ContainerLinearStyle)(item_decl.override.data)).separation
			}
	}

}

_layout_close :: proc() {
	pop(&layout_stack)
	container_idx = layout_state.items_decl[container_idx].parent_idx
}

_layout_text :: proc(text: string, style: ^TextStyle) -> int {
	allocator := mem.arena_allocator(&layout_state.text_arena)

	new_string := strings.clone(text, allocator)

	if container_idx != -1 {
		layout_state.items_decl[container_idx].num_children += 1
	}

	new_item_idx = len(layout_state.items_decl)
	append(&layout_state.items_decl, LayoutItemDeclaration {})
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.layout_hint = layout_hint
	layout_hint = nil

	item_decl.override = {TextStyle, style}
	item_decl.text = new_string
	

	return new_item_idx
}



LayoutItemDeclaration :: struct {
	children_layout: ChildrenLayout,
	slot_config: int,
	parent_idx: int,
	end: int,
	num_children: int,
	padding: BoxOffsets,
	color: Color,
	box_style: BoxStyle,
	layout_hint: LayoutHint, // hint to layout within parent
	text: string,
	comment: string,
	override: StyleOverride,
	handler: PointerHandler,
	handler_data: rawptr,
	custom: Layout_Custom_Data,
}

LayoutItemResult :: struct {
	fit_size: f32x2,
	weight_sum: f32,
    layout_rect: Rect,
	pointer_rect: Rect,
	color: Color,
	hovered: bool,
	hover_leaf: bool,
	focused: bool,
}

// will hold last computed layout state. It will also hold data needed to resolve mouse events.
// It will take into account themes data like padding as it matters to layout. but other things like colors will be kept as pointers to point to them when drawing

LayoutState :: struct {
//    rect: Rect,
	items_decl: [dynamic]LayoutItemDeclaration,
	items_tree: [dynamic]LayoutItemResult,
	layout_idx_current: int,
	layout_idx_parent: int,

	computed_mem: []byte,
	computed_arena: mem.Arena,

	text_arena_mem : []byte,
	text_arena: mem.Arena,

}

layout_state: LayoutState

_layout_compute :: proc() {
	// fitting pass: goes over everything to tell what are the minimum sizes desired for things
	// IDEA: maybe the fitting pass could be moved to happen in the layout declaration pass?
	layout_cursor = 0
	_layout_item()

	layout_state.items_tree[0].layout_rect = {0, 0, current_layout_dimensions.x, current_layout_dimensions.y}
	// filling pass: distributes available space in children, evaluates weights and aligns items
	layout_cursor = 0
	_layout_filling()

	layout_cursor = 0
	//print_layout_result()
}

layout_cursor := 0
_layout_item :: proc() -> int {
	index := layout_cursor
	layout_cursor += 1
	assert(index == len(layout_state.items_tree))
	layout_state.layout_idx_current = index
	
	append(&layout_state.items_tree, LayoutItemResult {})

	layout_state.items_tree[index].color = layout_state.items_decl[index].color

	item := layout_state.items_decl[index]

	fit_size: f32x2
	weight_sum: f32

	for idx in 0..<item.num_children {
		created_item_idx :=_layout_item()
		child_item := layout_state.items_decl[created_item_idx]
		child_result := layout_state.items_tree[created_item_idx]
		switch children_layout in item.children_layout {
			case Layout_Extend:
					fit_size.x = max(fit_size.x, child_result.fit_size.x)
					fit_size.y = max(fit_size.y, child_result.fit_size.y)
			case Layout_Overlay_Float:
					fit_size.x = max(fit_size.x, child_result.fit_size.x)
					fit_size.y = max(fit_size.y, child_result.fit_size.y)
			
			case Layout_Scroll:
				fit_size.x = max(fit_size.x, child_result.fit_size.x)
				fit_size.y = max(fit_size.y, child_result.fit_size.y)
				if children_layout.vertical {
					fit_size.y = 0
				}
				if children_layout.horizontal {
					fit_size.x = 0
				}

			case Layout_Linear_Horizontal:
					fit_size.y = max(fit_size.y, child_result.fit_size.y)
					ignore_fit := false
					hint, ok := child_item.layout_hint.(LinearChildSizingFixed)
					if ok {
						if hint.width.type == .Weight {
							weight_sum += hint.width.amount
						}
						if hint.width.type == .DensityPixels {
							fit_size.x = hint.width.amount
						}
						if hint.width.type == .RealPixels {
							fit_size.x = hint.width.amount
						}
						ignore_fit = .IgnoreFit in hint.width.flags
					}
					if !ignore_fit {
						fit_size.x += child_result.fit_size.x
					}


			case Layout_Linear_Vertical:
					fit_size.x = max(fit_size.x, child_result.fit_size.x)
					hint, ok := child_item.layout_hint.(LinearChildSizingFixed)
					if ok && hint.height.type == .Weight {
						weight_sum += hint.height.amount
					} 
					if .IgnoreFit not_in hint.height.flags {
						fit_size.y += child_result.fit_size.y
					}
		}
	}
	layout_state.items_decl[index].end = layout_cursor

	#partial switch children_layout in item.children_layout {

		case Layout_Linear_Horizontal:
			separation := children_layout.separation
			if item.num_children > 1 {
				separation = border_apply(children_layout.separation_flags, separation)
				fit_size.x += separation * f32(item.num_children - 1)
			}
		case Layout_Linear_Vertical:
			separation := children_layout.separation
			if item.num_children > 1 {
				separation = border_apply(children_layout.separation_flags, separation)
				fit_size.y += separation * f32(item.num_children - 1)
			}
	}

	fit_size.x += item.padding.left + item.padding.right
	fit_size.y += item.padding.top + item.padding.bottom

	if item.override.type == TextStyle {
		text_style := (^TextStyle)(item.override.data)
		text_calc_size := measure_text(item.text, text_style.font, text_style.size)
		fit_size.x += text_calc_size.x
		fit_size.y += text_calc_size.y
	}

	layout_result := &layout_state.items_tree[index]
	layout_result.fit_size = fit_size
	layout_result.weight_sum = weight_sum

	
	return index
}

_layout_filling :: proc() {
	index := layout_cursor
	layout_cursor += 1

	item_decl := layout_state.items_decl[index]
	item_tree := layout_state.items_tree[index]

	available_size := item_tree.layout_rect
	available_size.x += item_decl.padding.left
	available_size.w -= (item_decl.padding.left + item_decl.padding.right)
	available_size.y += item_decl.padding.top
	available_size.h -= (item_decl.padding.top + item_decl.padding.bottom)

	size_to_spread: f32
	separation: f32
	cursor_along: f32

	#partial switch layout in item_decl.children_layout {
		case Layout_Linear_Horizontal:
			size_to_spread = available_size.w - item_tree.fit_size.x
			separation = border_apply(layout.separation_flags, layout.separation)
			//size_to_spread -= f32(item_decl.num_children-1) * separation
			cursor_along = available_size.x
		case Layout_Linear_Vertical:
			size_to_spread = available_size.h - item_tree.fit_size.y
			separation = border_apply(layout.separation_flags, layout.separation)
			//size_to_spread -= f32(item_decl.num_children-1) * separation
			cursor_along = available_size.y
	}
	if item_tree.weight_sum != 0 {
		size_to_spread = size_to_spread / item_tree.weight_sum
	}



	for idx in 0..<item_decl.num_children {
		child_decl := layout_state.items_decl[layout_cursor]
		child_tree := &layout_state.items_tree[layout_cursor]
		#partial switch layout in item_decl.children_layout {
			case Layout_Linear_Horizontal:
				child_tree.layout_rect.x = cursor_along
				child_width: f32 = 0
				sizing_across := SizingAcross.Fill
				ignore_fit_size := false
				if layout_hint, has_layout_hint := child_decl.layout_hint.(LinearChildSizingFixed); has_layout_hint {
					if .Debug in layout_hint.width.flags {
						fmt.print("")
					}
					sizing_across = layout_hint.across
					ignore_fit_size = .IgnoreFit in layout_hint.width.flags
					if layout_hint.width.type == .Weight {
						child_width = size_to_spread * layout_hint.width.amount
					}
					
					
				}
				if !ignore_fit_size {
					child_width += child_tree.fit_size.x
				}

				child_tree.layout_rect.w = child_width
				child_tree.layout_rect.x = cursor_along
				cursor_along += child_width
				
				switch sizing_across {
					case .Fill:
						child_tree.layout_rect.y = available_size.y
						child_tree.layout_rect.h = available_size.h
					case .Begin:
						child_tree.layout_rect.y = available_size.y
						child_tree.layout_rect.h = child_tree.fit_size.y
					case .Center:
						child_tree.layout_rect.y = available_size.y + (available_size.h - child_tree.fit_size.y) * 0.5
						child_tree.layout_rect.h = child_tree.fit_size.y
					case .End:
						child_tree.layout_rect.y = available_size.y + available_size.h - child_tree.fit_size.y
						child_tree.layout_rect.h = child_tree.fit_size.y
				}
				
			case Layout_Linear_Vertical:
				child_tree.layout_rect.y = cursor_along
				child_height: f32 = 0
				sizing_across := SizingAcross.Fill
				ignore_fit_size := false
				if layout_hint, ok := child_decl.layout_hint.(LinearChildSizingFixed); ok {
					sizing_across = layout_hint.across
					ignore_fit_size = .IgnoreFit in layout_hint.height.flags
					if layout_hint.height.type == .Weight {
						child_height = size_to_spread * layout_hint.height.amount
					}
				}
				
				if !ignore_fit_size { // fallback to .Fit
					child_height += child_tree.fit_size.y
				}

				child_tree.layout_rect.h = child_height
				child_tree.layout_rect.y = cursor_along
				cursor_along += child_height
				
				switch sizing_across {
					case .Fill:
						child_tree.layout_rect.x = available_size.x
						child_tree.layout_rect.w = available_size.w
					case .Begin:
						child_tree.layout_rect.x = available_size.x
						child_tree.layout_rect.w = child_tree.fit_size.x
					case .Center:
						child_tree.layout_rect.x = available_size.x + (available_size.w - child_tree.fit_size.x) * 0.5
						child_tree.layout_rect.w = child_tree.fit_size.x
					case .End:
						child_tree.layout_rect.x = available_size.x + available_size.w - child_tree.fit_size.x
						child_tree.layout_rect.w = child_tree.fit_size.x
				}
			case Layout_Scroll:
				scroll := layout.offset
				child_tree.layout_rect.x = available_size.x - scroll.x
				child_tree.layout_rect.y = available_size.y - scroll.y
				child_tree.layout_rect.w = max(child_tree.fit_size.x, available_size.x)
				child_tree.layout_rect.h = max(child_tree.fit_size.y, available_size.y)

			case Layout_Extend, Layout_Overlay_Float:
				sizing_x := ChildSizingAxis.Fill
				sizing_y := ChildSizingAxis.Fill
				if layout_hint, ok := child_decl.layout_hint.(OverlayChildSizing); ok {
					sizing_x = layout_hint.sizing_x
					sizing_y = layout_hint.sizing_y
				}

				switch sizing_x {
					case .Fill:
						child_tree.layout_rect.x = available_size.x
						child_tree.layout_rect.w = available_size.w
					case .Begin:
						child_tree.layout_rect.x = available_size.x
						child_tree.layout_rect.w = child_tree.fit_size.x
					case .Middle:
						child_tree.layout_rect.x = available_size.x + (available_size.w - child_tree.fit_size.x) * 0.5
						child_tree.layout_rect.w = child_tree.fit_size.x
					case .End:
						child_tree.layout_rect.x = available_size.x + available_size.w - child_tree.fit_size.x
						child_tree.layout_rect.w = child_tree.fit_size.x
				}

				switch sizing_y {
					case .Fill:
						child_tree.layout_rect.y = available_size.y
						child_tree.layout_rect.h = available_size.h
					case .Begin:
						child_tree.layout_rect.y = available_size.y
						child_tree.layout_rect.h = child_tree.fit_size.y
					case .Middle:
						child_tree.layout_rect.y = available_size.y + (available_size.h - child_tree.fit_size.y) * 0.5
						child_tree.layout_rect.h = child_tree.fit_size.y
					case .End:
						child_tree.layout_rect.y = available_size.y + available_size.h - child_tree.fit_size.y
						child_tree.layout_rect.h = child_tree.fit_size.y
				}
				

		}
		cursor_along += separation
		
		_layout_filling()
	}
}



layout_process_event :: proc(event: ^PointerEvent) {

	if len(layout_state.items_decl) == 0 {
		return
	}

	event.event.phase = .Capturing

	layout_cursor = 0
	indent = 0
	layout_process_event_item(event)
}

LOG_POINTER_EVENTS :: false

layout_process_event_item :: proc(event: ^PointerEvent) {

	index := layout_cursor
	
	item_decl := layout_state.items_decl[index]
	item_tree := layout_state.items_tree[index]

	// todo: check drag-release-out interaction
	// todo: check drag with touch in scroll views
	cursor_hovers := abm.point_in_rect(event.coords, item_tree.layout_rect) 
	if cursor_hovers {
		when LOG_POINTER_EVENTS {
			for idx in 0..<indent {
				fmt.print("    ")
			}
			fmt.println(event.event.phase, index, item_tree)
		}

		if item_decl.handler != nil {
			item_decl.handler(event, item_decl.handler_data)
		
			if event.event.handled {
				fmt.println(event.event.phase, "handled", index, item_tree)
				// stop propagating inwards, event was handled in capturing phase
				return
			}
		}


		layout_cursor = index + 1

		for layout_cursor < item_decl.end {
			indent += 1
			layout_process_event_item(event)
			indent -= 1
			if event.event.handled {
				return
			}
		}
		
		event.event.phase = .Bubbling
		when LOG_POINTER_EVENTS {	
			for idx in 0..<indent {
				fmt.print("    ")
			}
			fmt.println(event.event.phase, index, item_tree)
		}
		if item_decl.handler != nil {
			item_decl.handler(event, item_decl.handler_data)
			when LOG_POINTER_EVENTS {
				if event.event.handled {
					fmt.println(event.event.phase, "handled", index, item_tree)
					// stop propagating inwards, event was handled in capturing phase
				}
			}
		}
	}

	layout_cursor = item_decl.end
}


