package ui

import "base:runtime"
import "engine:ui"
import "core:log"


layout_stack: [dynamic]ChildrenLayout


layout_begin :: proc(size: f32x2, scale_factor: f32) {

	if layout_hint != nil {
		log.info("layout hint:", layout_hint, "wasn't consumed in previous frame")
		layout_hint = nil
	}
	
	
	//assert(3 == 2)
	_layout_set_dimensions({f32(size.x), f32(size.y)})
	_layout_set_default_config()
	_layout_begin(scale_factor)

	append(&layout_stack, Layout_Overlay_Float{})
}

layout_end :: proc() {
	pop(&layout_stack)
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

layout_container :: proc(children_layout: ChildrenLayout, style: ^StyleClass = nil,  maybe_tag:Maybe(string) = nil) {

	_layout_create(children_layout)

	if style != nil {
		box_style := get_current_style(&style_tab_bar, BoxStyleColored)
		_layout_open_styled(style=box_style)
	} else {
		_layout_open()
	}
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


class_btn := style_class("Button")

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
