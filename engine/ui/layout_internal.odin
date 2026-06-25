package ui

import "core:strings"
import "core:mem"
import "core:fmt"
import clay "../clay-odin"

f32x2 :: [2]f32
Rect :: struct {
    x, y, w, h: f32
}

current_layout_dimensions: f32x2
text_config_default: ^clay.TextElementConfig

render_commands: clay.ClayArray(clay.RenderCommand)

_layout_set_dimensions :: proc(size: f32x2) {

    current_layout_dimensions = size
    clay.SetLayoutDimensions({current_layout_dimensions.x, current_layout_dimensions.y})
	

}

scale_factor: f32 = 1

text_round_policy := RoundingPolicy.Round

_layout_set_default_config :: proc() {
   	text_config_default = clay.TextConfig(
		{
			textColor = {1,1,1,1},
			fontSize = u16(scaling_apply(text_round_policy, 14 * scale_factor)), // clay expects an integer here
			textAlignment = .Left,
		},
	)

}

text_arena_mem : [1024*1024]u8
text_arena: mem.Arena

_layout_begin :: proc(in_scale_factor: f32) {
	mem.arena_init(&text_arena, text_arena_mem[:])
    scale_factor = in_scale_factor
   	clay.BeginLayout()
	clear(&layout_state.items_decl)	
	clear(&layout_state.items_tree)
	layout_state = {}
	container_idx = -1
}


_layout_end :: proc() {
	_layout_compute()
	render_commands = clay.EndLayout()
}


clay_elem: clay.ElementDeclaration
child_layout: ChildrenLayout
container_idx: int


new_item_idx: int

_layout_create :: proc(in_child_layout: ChildrenLayout) {
	if container_idx != -1 {
		layout_state.items_decl[container_idx].num_children += 1
	}

	child_layout = in_child_layout
   	clay._OpenElement()
	clay_elem = {}

	new_item_idx = len(layout_state.items_decl)
	append(&layout_state.items_decl, LayoutItemDeclaration {})
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.layout_hint = layout_hint


    apply_decl(&clay_elem, child_layout)
	append(&layout_stack, child_layout)
}

_layout_open :: proc(comment: string = "") {
    clay.ConfigureOpenElement(DPI(clay_elem))
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.children_layout = child_layout
	item_decl.parent_idx = container_idx

	p := clay_elem.layout.padding
	item_decl.padding = {f32(p.left), f32(p.right), f32(p.top), f32(p.bottom)}

	item_decl.color = clay_elem.backgroundColor
	item_decl.comment = comment
	
	
	container_idx = new_item_idx
}

_layout_close :: proc() {
	pop(&layout_stack)
	clay._CloseElement()
	container_idx = layout_state.items_decl[container_idx].parent_idx
}

_layout_text :: proc(text: string, size: u16, font: u16) -> int {
	allocator := mem.arena_allocator(&text_arena)

	new_string := strings.clone(text, allocator)

	if container_idx != -1 {
		layout_state.items_decl[container_idx].num_children += 1
	}

	new_item_idx = len(layout_state.items_decl)
	append(&layout_state.items_decl, LayoutItemDeclaration {})
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.layout_hint = layout_hint

	item_decl.is_text = true
	item_decl.text = new_string
	item_decl.text_font = font
	item_decl.text_size = size
	return new_item_idx
}



LayoutItemDeclaration :: struct {
	children_layout: ChildrenLayout,
	slot_config: int,
	parent_idx: int,
	num_children: int,
	padding: BoxOffsets,
	color: Color,
	layout_hint: LayoutHint, // hint to layout within parent
	is_text: bool,
	text: string,
	text_font: u16,
	text_size: u16,
	comment: string,
}

LayoutItemResult :: struct {
	fit_size: f32x2,
	weight_sum: f32,
    layout_rect: Rect,
	pointer_rect: Rect,
	color: Color,
}

// will hold last computed layout state. It will also hold data needed to resolve mouse events.
// It will take into account themes data like padding as it matters to layout. but other things like colors will be kept as pointers to point to them when drawing

LayoutState :: struct {
    rect: Rect,
	items_decl: [dynamic]LayoutItemDeclaration,
	items_tree: [dynamic]LayoutItemResult,
	layout_idx_current: int,
	layout_idx_parent: int,
}

layout_state: LayoutState

_layout_compute :: proc() {
	// fitting pass: goes over everything to tell what are the minimum sizes desired for things
	layout_cursor = 0
	_layout_item()

	layout_state.items_tree[0].layout_rect = {0, 0, current_layout_dimensions.x, current_layout_dimensions.y}
	// filling pass: distributes available space in children, evaluates weights and aligns items
	layout_cursor = 0
	_layout_filling()

	layout_cursor = 0
	//print_layout_result()
}

indent: int = 0
print_layout_result :: proc() {
	fmt.println()
	fmt.println()
	fmt.println()
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

	if item.comment == "layers" {
		//fmt.printf("", i32(2))
	}

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
			case Layout_Linear_Horizontal:
					fit_size.y = max(fit_size.y, child_result.fit_size.y)
					hint, ok := child_item.layout_hint.(LinearChildSizingFixed)
					if ok && hint.width.type == .Weight {
						weight_sum += hint.width.amount
					} else {
						fit_size.x += child_result.fit_size.x
					}
			case Layout_Linear_Vertical:
					fit_size.x = max(fit_size.x, child_result.fit_size.x)
					hint, ok := child_item.layout_hint.(LinearChildSizingFixed)
					if ok && hint.height.type == .Weight {
						weight_sum += hint.height.amount
					} else {
						fit_size.y += child_result.fit_size.y
					}
		}
	}

	layout_result := &layout_state.items_tree[index]
	layout_result.fit_size = fit_size
	layout_result.weight_sum = weight_sum

	#partial switch children_layout in item.children_layout {

		case Layout_Linear_Horizontal:
			if item.num_children > 1 {
				layout_result.fit_size.x += children_layout.separation * f32(item.num_children - 1)
			}
		case Layout_Linear_Vertical:
			if item.num_children > 1 {
				layout_result.fit_size.y += children_layout.separation * f32(item.num_children - 1)
			}
	}

	//calc_fit_size()
	layout_result.fit_size.x += item.padding.left + item.padding.right
	layout_result.fit_size.y += item.padding.top + item.padding.bottom

	if item.is_text {
		text_calc_size := measure_text(item.text, item.text_font, item.text_size)
		layout_result.fit_size.x += text_calc_size.x
		layout_result.fit_size.y += text_calc_size.y
	}


	if item.comment == "layers" {
		//fmt.printf("", i32(2))
	}


	
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
			separation = layout.separation
			cursor_along = available_size.x
		case Layout_Linear_Vertical:
			size_to_spread = available_size.h - item_tree.fit_size.y
			separation = layout.separation
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
				child_width: f32 = -1
				sizing_across := SizingAcross.Fill
				if layout_hint, ok := child_decl.layout_hint.(LinearChildSizingFixed); ok {
					sizing_across = layout_hint.across
					if layout_hint.width.type == .Weight {
						child_width = size_to_spread * layout_hint.width.amount
					}
				}
				if child_width == -1 { // fallback to .Fit
					child_width = child_tree.fit_size.x
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
				child_height: f32 = -1
				sizing_across := SizingAcross.Fill
				if layout_hint, ok := child_decl.layout_hint.(LinearChildSizingFixed); ok {
					sizing_across = layout_hint.across
					if layout_hint.height.type == .Weight {
						child_height = size_to_spread * layout_hint.height.amount
					}
				}
				if child_height == -1 { // fallback to .Fit
					child_height = child_tree.fit_size.y
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

	if item_decl.comment == "layers" {
		//fmt.printf("", i32(2))
	}

	
}



apply_decl :: proc(elem: ^clay.ElementDeclaration, children_layout: ChildrenLayout) {

	direction: clay.LayoutDirection
	#partial switch c in children_layout {
		case Layout_Linear_Horizontal:
			direction = .LeftToRight
			elem.layout.childGap = u16(c.separation)
		case Layout_Linear_Vertical:
			direction = .TopToBottom
			elem.layout.childGap = u16(c.separation)
	}
	elem.layout.layoutDirection = direction


	item_sizing := clay.Sizing {}

	item_floating := clay.FloatingElementConfig {}

	current := layout_stack[len(layout_stack)-1]
	switch layout in current {
		case Layout_Overlay_Float:
			item_floating.attachTo = .Parent
			rule := OverlayChildSizing {}

			if cached_rule, ok := layout_hint.(OverlayChildSizing); ok {
				rule = cached_rule
				layout_hint = nil // is this really necessary/desired?
			}
		
			if rule.sizing_x == .Fill {
				item_sizing.width = {type = .Percent, constraints = {sizePercent = 1}}
			} else {
				item_sizing.width = {type = .Fit}
			}
			if rule.sizing_y == .Fill {
				item_sizing.height = {type = .Percent, constraints = {sizePercent = 1}}
			} else {
				item_sizing.height = {type = .Fit}
			}
			point: clay.FloatingAttachPointType
			if rule.sizing_x == .Fill && rule.sizing_y == .Begin {  point = .LeftTop }
			if rule.sizing_x == .Fill && rule.sizing_y == .Fill {   point = .LeftTop }
			if rule.sizing_x == .Fill && rule.sizing_y == .Middle { point = .LeftCenter }
			if rule.sizing_x == .Fill && rule.sizing_y == .End {    point = .LeftBottom }
			if rule.sizing_x == .Begin && rule.sizing_y == .Begin {	 point = .LeftTop }
			if rule.sizing_x == .Begin && rule.sizing_y == .Fill {   point = .LeftTop }
			if rule.sizing_x == .Begin && rule.sizing_y == .Middle { point = .LeftCenter }
			if rule.sizing_x == .Begin && rule.sizing_y == .End {    point = .LeftBottom }
			if rule.sizing_x == .Middle && rule.sizing_y == .Begin {  point = .CenterTop }
			if rule.sizing_x == .Middle && rule.sizing_y == .Fill {   point = .CenterTop }
			if rule.sizing_x == .Middle && rule.sizing_y == .Middle { point = .CenterCenter }
			if rule.sizing_x == .Middle && rule.sizing_y == .End {    point = .CenterBottom }
			if rule.sizing_x == .End && rule.sizing_y == .Begin {	 point = .RightTop }
			if rule.sizing_x == .End && rule.sizing_y == .Fill {	 point = .RightTop }
			if rule.sizing_x == .End && rule.sizing_y == .Middle { point = .RightCenter }
			if rule.sizing_x == .End && rule.sizing_y == .End {    point = .RightBottom }
			
			item_floating.attachment.element = point
			item_floating.attachment.parent = point

		case Layout_Extend:
			// we shouldn't need this, but clay can't do overlay layout without 
			// using "floating". but then the children won't affect parents during layout.
			//
			// So for now, we have layout_extend which is like overlay, but demands using only one child

			rule := OverlayChildSizing {}
			
			if cached_rule, ok := layout_hint.(OverlayChildSizing); ok {
				rule = cached_rule
				layout_hint = nil // is this really necessary/desired?
			}
		
			if rule.sizing_x == .Fill {
				item_sizing.width = {type = .Grow}
			} else {
				item_sizing.width = {type = .Fit}
			}
			if rule.sizing_y == .Fill {
				item_sizing.height = {type = .Grow}
			} else {
				item_sizing.height = {type = .Fit}
			}
		
		case Layout_Linear_Horizontal:
			rule := LinearChildSizingFixed {}
			rule.height = {type = .Weight} // in horizontal containers, elements fill vertically by default
			if in_rule, ok := layout_hint.(LinearChildSizingFixed); ok {
				rule = in_rule
				layout_hint = nil
			}
			item_sizing.width = convert_to_clay_rule(rule.width)
			item_sizing.height = convert_to_clay_rule(rule.height)
			//log.info(maybe_tag, item_sizing)
		case Layout_Linear_Vertical:
			rule := LinearChildSizingFixed {}
			rule.width = {type = .Weight} // in vertical containers, elements fill horizontally by default
			if in_rule, ok := layout_hint.(LinearChildSizingFixed); ok {
				rule = in_rule
				layout_hint = nil
			}
			item_sizing.width = convert_to_clay_rule(rule.width)
			item_sizing.height = convert_to_clay_rule(rule.height)
			//log.info(maybe_tag, item_sizing)
	}

	elem.layout.sizing = item_sizing
	elem.floating = item_floating
}
