package ui

import "base:runtime"
import "engine:ui"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:c"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import "../gfx"
import abm "../math"
import "../fs"


layout_stack: [dynamic]ChildrenLayout

_ui_inited := false


init :: proc() {
	if !_ui_inited {
		text_config_default = new(TextStyle)
		text_config_default.size = 14
		text_config_default.color = Color32{full=0xFFFFFFFF}
		text_config_default.font = default_font_id

		init_fonts()

		_nav_init()

		_ui_inited = true
	}
}

layout_begin_window :: proc(window_id: Window_ID = 0) {
	window := windows[window_id]
	surface := surfaces[window.surface_id]
	pixel_size := window_pixel_size(window_id)
	layout_begin_rect(f32x2{f32(pixel_size.x), f32(pixel_size.y)}, surface.dpi)
}

layout_begin_rect :: proc(pixel_size: f32x2, in_scale_factor: f32) {
	
	scale_factor_window = in_scale_factor if in_scale_factor > 0 else 1
	scale_factor = scale_factor_user * scale_factor_window

	if layout_hint != nil {
		log.info("layout hint:", layout_hint, "wasn't consumed in previous frame")
		layout_hint = nil
	}
	
	_layout_set_dimensions({f32(pixel_size.x), f32(pixel_size.y)})
	_layout_set_default_config()
	_layout_begin(scale_factor)

	_layout_create(Layout_Overlay_Float{})
	_layout_open("--root--")
}

layout_begin :: proc {
	layout_begin_rect,
	layout_begin_window,
}

debug_guard := false
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

Layout_Scroll :: struct {
	vertical: bool,
	horizontal: bool,
	offset: ^f32x2,
}

ChildrenLayout :: union #no_nil {
	Layout_Extend,
	Layout_Overlay_Float,
	Layout_Linear_Horizontal,
	Layout_Linear_Vertical,
	Layout_Scroll,
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

scroll_handler :: proc(event: ^PointerEvent, user_data: rawptr) {
	if event.phase == .Bubbling {
		if event.type == .Mouse {
			if event.sdl_event.type == SDL.EventType.MOUSE_WHEEL {
				wheel_evt := event.sdl_event.wheel
				decl := &layout_state.items_decl[event.current_idx]
				item := &layout_state.items_tree[event.current_idx]
				item_rect := item.layout_rect
				layout_scroll := (decl.children_layout.(Layout_Scroll))
				offset := layout_scroll.offset

				child_rect := &layout_state.items_tree[event.current_idx+1].layout_rect
				max_offset := [2]f32{child_rect.w - item_rect.w, child_rect.h - item_rect.h }

				if layout_scroll.vertical {
					offset.y += -wheel_evt.y * 24
					offset.y = clamp(offset.y, 0, max_offset.y)
				}
				if layout_scroll.horizontal {
					offset.x += wheel_evt.x * 24
					offset.x = clamp(offset.x, 0, max_offset.x)
				}
			}
		}
	}

}

layout_scrollview :: proc(offset: ^f32x2, maybe_tag:Maybe(string) = nil, in_horizontal: bool = false, in_vertical: bool = true) {

	idx := len(layout_state.items_decl)

	_layout_create(Layout_Scroll{vertical=in_vertical, horizontal=in_horizontal, offset=offset})

	scroll_style := BoxStyleColored {
		border_color=Color{1,1,0,1},
		border_width={2,2,2,2},
	}
	_layout_open_styled("scroll", &scroll_style)

	user_ptr := &layout_state.items_decl[idx].children_layout.(Layout_Scroll)
	
	ui_pointer_handler(scroll_handler, user_ptr)

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
			allocator := mem.arena_allocator(&layout_state.computed_arena)
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
			item_decl.padding = scaled_padding(container_style.padding)
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

ModifierInstance :: struct {
	end_idx: int,
}
 
draw_modifiers : [dynamic]ModifierInstance

layout_draw :: proc() {

	clear(&draw_modifiers)

	num_items := len(layout_state.items_tree)
	for idx in 0..<num_items {
		for ;((len(draw_modifiers) != 0) && (draw_modifiers[len(draw_modifiers)-1].end_idx == idx)); {
			SDL.SetRenderClipRect(gfx.draw_context.renderer, nil)
			pop(&draw_modifiers)
		}

		decl := layout_state.items_decl[idx]
		item := layout_state.items_tree[idx]
		if decl.box_style != nil {
			rect := item.layout_rect
			SDL.SetRenderDrawColorFloat(gfx.draw_context.renderer, 1, 1, 1, 1)
			SDL.SetRenderDrawBlendMode(gfx.draw_context.renderer, {.BLEND})
			#partial switch v in decl.box_style {
				case BoxStyleColored:
					draw_box_styled(rect, v)
			}
		} else if item.color.a != 0 {
			rect := item.layout_rect
			SDL.SetRenderDrawColorFloat(gfx.draw_context.renderer, 1, 1, 1, 1)
			SDL.SetRenderDrawBlendMode(gfx.draw_context.renderer, {.BLEND})

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
		scroll, is_scroll := decl.children_layout.(Layout_Scroll)
		if is_scroll {
			rect := SDL.Rect{
				c.int(item.layout_rect.x),
				c.int(item.layout_rect.y),
				c.int(item.layout_rect.w),
				c.int(item.layout_rect.h),
			}
			
			SDL.SetRenderClipRect(gfx.draw_context.renderer, &rect)
			append(&draw_modifiers, ModifierInstance{decl.end})
		}

		if decl.override.type == TextStyle {
			text_style := (^TextStyle)(decl.override.data)
		
			cstr := cstring(raw_data(decl.text))


			//////////// when we handle horizontal alignment
			font_size := scaled_text_size(text_style.size)
			font := get_font_with_size(text_style.font, font_size)
			TTF.SetFontWrapAlignment(font, .LEFT)
			//

			// when we handle vertical alignment
			fit_size := item.fit_size
			draw_rect := item.layout_rect

			// if valign = middle:
			draw_rect.y += (draw_rect.h - fit_size.y) * 0.5
			
	
			sdl_text := get_text_with_font_size(text_style.font, font_size)
			color := text_style.color.channels
			TTF.SetTextColor(sdl_text, color.r, color.g, color.b, color.a)
			TTF.SetTextString(sdl_text, cstr, uint(len(decl.text)))
			TTF.DrawRendererText(sdl_text, draw_rect.x, draw_rect.y)
		}

		if decl.custom.callback_render != nil {
			decl.custom.callback_render(layout_state, idx)
		}
	}

		for ;(len(draw_modifiers) != 0); {
			SDL.SetRenderClipRect(gfx.draw_context.renderer, nil)
			pop(&draw_modifiers)
		}

}
