package ui

import "engine:ui"
import "core:log"

import clay "../clay-odin"


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

layout_overlay_child :: proc(rule: OverlayChildSizing) {
	if layout_hint != nil {
		log.error("unconsumed layout hint '", layout_hint, "' before pushing '", rule, "'")
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
}


layout_linear_child :: proc(rule: LinearChildSizingFixed) {
	if layout_hint != nil {
		log.error("unconsumed layout hint '", layout_hint, "' before pushing '", rule, "'")
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
}


convert_to_clay_rule :: proc(rule: Sizing) -> clay.SizingAxis {
	r: clay.SizingAxis
	switch rule.type {
		case .Fit:
			r = {type = .Fit, constraints = {sizeMinMax = {0,0}}}
		case .RealPixels:
			v := rule.amount
			r = {type = .Fit, constraints = {sizeMinMax = {v, v}}}
		case .DensityPixels:
			v := rule.amount * scale_factor
			r = {type = .Fit, constraints = {sizeMinMax = {v, v}}}
		case .Ratio:
			v := rule.amount
			r = {type = .Percent, constraints = {sizeMinMax = {v, v}}}
		case .Weight:
			v := f32(0) //rule.amount
			r = {type = .Grow, constraints = {sizeMinMax = {v, v}}}
	}
	return r
}

layout_scrollview :: proc(maybe_tag:Maybe(string) = nil) {

	_layout_create(ui.Layout_Extend{})
	
	clay_elem.clip = {
		vertical = true,
		childOffset = clay.GetScrollOffset(),
	}

	_layout_open()
	
}

layout_container :: proc(children_layout: ChildrenLayout, style: ^StyleClass = nil,  maybe_tag:Maybe(string) = nil) {

	_layout_create(children_layout)

	if style != nil {
		box_style := get_current_style(&style_tab_bar, BoxStyleColored)
		apply_style_box_colored(&clay_elem, box_style^)
	}

	_layout_open()
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

text_config: ^clay.TextElementConfig


config_box_style :: proc(elem: ^clay.ElementDeclaration, style: BoxStyle) {
	
	switch s in style {
		case BoxStyleColored:
			config_box_colored(elem, s)
		case BoxStyleTextured:
			config_box_textured(s)
	}
}



apply_style_box_colored :: proc(elem: ^clay.ElementDeclaration, style: BoxStyleColored) {

	elem.layout.padding = {
		u16(style.padding.left),
		u16(style.padding.right),
		u16(style.padding.top),
		u16(style.padding.bottom),
	}

	elem.backgroundColor = style.background
	
	elem.border = {
		color = style.border_color,
		width = {
			u16(style.border_width.w),
			u16(style.border_width.e),
			u16(style.border_width.n),
			u16(style.border_width.s),
			0,
		}	
	}
	elem.cornerRadius = transmute(clay.CornerRadius) style.corner_radii
}
	

config_box_colored :: proc(elem: ^clay.ElementDeclaration, style: BoxStyleColored) {

	elem.layout.padding = {
				u16(style.padding.left),
				u16(style.padding.right),
				u16(style.padding.top),
				u16(style.padding.bottom),
			}
	elem.backgroundColor = style.background
	elem.border = {
			color = style.border_color,
			width = {
				u16(style.border_width.w),
				u16(style.border_width.e),
				u16(style.border_width.n),
				u16(style.border_width.s),
				0,
			}
		}
	elem.cornerRadius = transmute(clay.CornerRadius) style.corner_radii

}

config_box_textured :: proc(style: BoxStyleTextured) {

}


layout_text_const :: proc($text: string, in_config: ^clay.TextElementConfig = nil) {
	config := in_config
	if config == nil {
		config = text_config_default
	}
	clay.Text(text, config)
}

layout_text_dynamic :: proc(text: string, in_config: ^clay.TextElementConfig = nil) {
	config := in_config
	if config == nil {
		config = text_config_default
	}
	clay.TextDynamic(text, config)
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
	if clay.Hovered() {
		style = &box_style.hover_box
	}

	config_box_style(&clay_elem, style^)

	_layout_open()
	
	text_style: ^TextStyle
	text_style = &box_style.idle_text
	
	layout_text(text)

	layout_close() // box
}
