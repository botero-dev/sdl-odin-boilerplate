package ui

import "base:runtime"
import "engine:ui"
import "core:log"
import "core:mem"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import "../gfx"
import abm "../math"


layout_stack: [dynamic]ChildrenLayout



init :: proc() {
	text_config_default = new(TextElementConfig)
	text_config_default.fontSize = 14

	_nav_init()

}


layout_begin :: proc(size: f32x2, scale_factor: f32) {

	if layout_hint != nil {
		log.info("layout hint:", layout_hint, "wasn't consumed in previous frame")
		layout_hint = nil
	}
	
	
	//assert(3 == 2)
	_layout_set_dimensions({f32(size.x), f32(size.y)})
	_layout_set_default_config()
	_layout_begin(scale_factor)

	_layout_create(Layout_Overlay_Float{})
	_layout_open("--root--")
}

layout_end :: proc() {
	_layout_close()
	if len(layout_stack) != 0 {
		log.error("layout_stack is not empty when finishing drawing.")
		log.error(layout_stack)
		clear(&layout_stack)
	}

	_layout_end()

}


LayoutDirection :: enum {
	Horizontal,
	Vertical,
}

Layout_Extend :: struct {}
Layout_Overlay_Float :: struct {}


Layout_Linear :: struct {
	// container state
	separation: f32,
	separation_flags: BorderFlags,
}

Layout_Linear_Horizontal :: distinct Layout_Linear
Layout_Linear_Vertical :: distinct Layout_Linear

ChildrenLayout :: union #no_nil {
	Layout_Extend,
	Layout_Overlay_Float,
	Layout_Linear_Horizontal,
	Layout_Linear_Vertical,
}


SizingType :: enum {
	Fit,
	DensityPixels,
	RealPixels,
	Weight,
	Ratio,
}


SizingFlags :: enum {
	IgnoreFit,          // if set, the container won't add child fit_size to container fit_size calculation
	Absolute,           // if set, it will use pixels as the amount to scale, otherwise the amount is a fraction of free space
	IgnoreScaleFactor,  // when absolute==1, if set, it won't apply scale factor to sizing amount when it is in absolute mode.
	Debug,
}
SizingBits :: bit_set[SizingFlags]

Sizing :: struct {
	flags: SizingBits,
	type: SizingType,
	amount: f32,
}

SizingAlong :: struct {
	// maybe come up with interesting rules like:
	//  * use weight but never below fit size
	//  * use ratio over remaining space or over full space
	type: SizingType,
	amount: f32,
}

SizingAcross :: enum {
	Fill,   // fill
	Begin,  // align to beggining (top, left)
	Center, // align to center
	End,    // align to end (bottom, right)
}

LinearChildSizingFixed :: struct {
	// along: Sizing,
	// across: Sizing,
	width: Sizing,
	height: Sizing,
	across: SizingAcross,
}

ChildSizingAxis :: enum {
	Fill = 0,
	Begin = 1,
	Middle = 2,
	End = 3,
}

OverlayChildSizing :: struct {
	sizing_x: ChildSizingAxis,
	sizing_y: ChildSizingAxis,
}

LayoutHint :: union {
	OverlayChildSizing,
	LinearChildSizingFixed,
}

layout_hint: LayoutHint
layout_hint_loc: runtime.Source_Code_Location

layout_overlay_child :: proc(rule: OverlayChildSizing, loc := #caller_location) {
	if layout_hint != nil {
		log.error("unconsumed layout hint set at:", layout_hint_loc, layout_hint, "' before pushing '", rule, "'")
	}

	current := layout_stack[len(layout_stack)-1]
	#partial switch v in current {
		case Layout_Overlay_Float:
			break;
		case Layout_Extend:
			break;
		case:
			log.error("bad rule:", rule, " for current parent:", current)
	}

	layout_hint = rule
	layout_hint_loc = loc
}


layout_linear_child :: proc(rule: LinearChildSizingFixed, loc := #caller_location) {
	if layout_hint != nil {
		log.error("unconsumed layout hint set at:", layout_hint_loc, layout_hint, "' before pushing '", rule, "'")
	}

	current := layout_stack[len(layout_stack)-1]
	#partial switch v in current {
		case Layout_Linear_Horizontal:
			break;
		case Layout_Linear_Vertical:
			break;
		case:
			log.error("bad rule:", rule, " for current parent:", current)
	}

	layout_hint = rule
	layout_hint_loc = loc
}


layout_scrollview :: proc(maybe_tag:Maybe(string) = nil) {

	_layout_create(ui.Layout_Extend{})
	
	_layout_open()
	
}

style_container :: proc(offsets: Maybe(BoxOffsets) = nil, separation: Maybe(f32) = nil) -> WithOverrides(ContainerLinearStyle) {
	result: WithOverrides(ContainerLinearStyle)
	if offsets != nil {
		result.padding = offsets.?
		result.set_fields += {0}
	}
	if separation != nil {
		result.separation = separation.?
		result.set_fields += {1}
	}
	return result
}

layout_container_new :: proc(
	children_layout: ChildrenLayout, 
	overrides: WithOverrides(ContainerLinearStyle),
	style: ^StyleClass = nil,
	maybe_tag:Maybe(string) = nil
) {
	_layout_create(children_layout)

		container_style: ^ContainerLinearStyle
		if style != nil {
			container_style = get_current_style(style, ContainerLinearStyle)
		}

		if overrides.set_fields != {} {
			allocator := mem.arena_allocator(&computed_arena)
			collapsed_style := new(ContainerLinearStyle, allocator)
			if container_style != nil {
				collapsed_style^ = container_style^
			} else {
				collapsed_style^ = {}
			}
			
			if 0 in overrides.set_fields {
				collapsed_style.padding = overrides.padding
			}
			if 1 in overrides.set_fields {
				collapsed_style.separation = overrides.separation
			}
			if 2 in overrides.set_fields {
				// we don't use per-field overrides for visual things.
				collapsed_style.box_style = overrides.box_style
			}
			container_style = collapsed_style
		}

		_layout_open_styled(style=container_style)
		
		// hack:
		if container_style != nil {
			item_decl := &layout_state.items_decl[new_item_idx]
			item_decl.padding = container_style.padding
			item_decl.box_style = container_style.box_style
		}

}

layout_container_old :: proc(children_layout: ChildrenLayout, style: ^StyleClass = nil,  maybe_tag:Maybe(string) = nil) {

	_layout_create(children_layout)

	if style != nil {
		box_style := get_current_style(style, BoxStyleColored)
		_layout_open_styled(style=box_style)
	} else {
		_layout_open()
	}
}

layout_container :: proc {
	layout_container_old,
	layout_container_new,
}

DEBUG := false

layout_close :: proc() {
	_layout_close()
}

layout_custom :: proc(custom_data: Layout_Custom_Data) {
	_layout_create(Layout_Extend{})
	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.custom = custom_data
	
	_layout_open()
	_layout_close()
}



text_config: ^TextElementConfig



layout_text_const :: proc($text: string, in_config: ^TextElementConfig = nil) {
	config := in_config
	if config == nil {
		config = text_config_default
	}
	_layout_text(text, config.fontSize, config.fontId)	
}

layout_text_dynamic :: proc(text: string, in_config: ^TextElementConfig = nil) {
	config := in_config
	if config == nil {
		config = text_config_default
	}
	_layout_text(text, config.fontSize, config.fontId)
}

layout_text :: proc {
	layout_text_const,
	layout_text_dynamic,
}

layout_textbox :: proc(text: string, variant: ^StyleClass = nil, info: ^HandlerInfo = nil) {

	box_style := get_current_style(&class_btn, ButtonStyle)

	style: ^BoxStyle
	// switch button state
	style = &box_style.idle_box

	_layout_create(Layout_Linear_Horizontal{})

	ui_add_button(text, info)

	_layout_open()
	
	text_style: ^TextStyle
	text_style = &box_style.idle_text
	
	layout_text(text)

	layout_close() // box
}



layout_draw :: proc() {
	num_items := len(layout_state.items_tree)
	for idx in 0..<num_items {
		decl := layout_state.items_decl[idx]
		item := layout_state.items_tree[idx]
		if decl.box_style != nil {
			rect := item.layout_rect
			SDL.SetRenderDrawColorFloat(gfx.renderer, 1, 1, 1, 1)
			SDL.SetRenderDrawBlendMode(gfx.renderer, {.BLEND})
			#partial switch v in decl.box_style {
				case BoxStyleColored:
					draw_box_styled(rect, v)
			}
		} else if item.color.a != 0 {
			rect := item.layout_rect
			SDL.SetRenderDrawColorFloat(gfx.renderer, 1, 1, 1, 1)
			SDL.SetRenderDrawBlendMode(gfx.renderer, {.BLEND})

			c := item.color
			c.a = 1

			if decl.override.type == BoxStyleColored {
				box_style := (^BoxStyleColored)(decl.override.data)
				draw_box_styled(rect, box_style^)
			} else if decl.override.type == BoxStyle {
				box_style := (^BoxStyle)(decl.override.data)
				#partial switch v in box_style {
					case BoxStyleColored:
						draw_box_styled(rect, v)
				}
			} else if decl.override.type == ButtonStyle {
				button_style := (^ButtonStyle)(decl.override.data)
				hovered := abm.point_in_rect(coords, rect)
				if hovered {
					draw_box_styled(rect, button_style.hover_box.(BoxStyleColored))
				} else {
					draw_box_styled(rect, button_style.idle_box.(BoxStyleColored))
				}
			} else {
				corners := gfx.CornerRadii {4,4,4,4}
				gfx.draw_box_filled(rect, corners, c)
			}

		}
		if decl.is_text {
			cstr := cstring(raw_data(decl.text))
		    sdl_text := get_text_with_font_size(decl.text_font, decl.text_size)
			TTF.SetTextColor(sdl_text, 255, 255, 255, 255)
			TTF.SetTextString(sdl_text, cstr, uint(len(decl.text)))
			TTF.DrawRendererText(sdl_text, f32(item.layout_rect.x), f32(item.layout_rect.y))
		}

		if decl.custom.callback_render != nil {
			decl.custom.callback_render(layout_state, idx)
		}
	}
}
