package ui

import "core:log"

import clay "../clay-odin"
import ab ".."


render_commands: clay.ClayArray(clay.RenderCommand)

text_config_default: ^clay.TextElementConfig

layout_begin :: proc() {
	//assert(3 == 2)
	clay.SetLayoutDimensions({f32(ab.win_size.x), f32(ab.win_size.y)})
	text_config_default = clay.TextConfig(
		{
			fontId = ab.default_font_id,
			textColor = {1,1,1,1},
			fontSize = ab.border_policy(14),
			textAlignment = .Left,
		},
	)
	
	clay.BeginLayout()
}

layout_end :: proc() {
	render_commands = clay.EndLayout()
}

layout_draw :: proc() {
	ab.render_layout(&render_commands)
}

LayoutDirection :: enum {
	Horizontal,
	Vertical,
}

Layout_Overlay :: struct {}

Layout_Linear :: struct {
	separation: f32,
}

Layout_Linear_Horizontal :: distinct Layout_Linear
Layout_Linear_Vertical :: distinct Layout_Linear

ChildrenLayout :: union #no_nil {
	Layout_Overlay,
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

Sizing :: struct {
	type: SizingType,
	amount: f32,
}

LinearChildSizingFixed :: struct {
	// along: Sizing,
	// across: Sizing,
	width: Sizing,
	height: Sizing,
}

cache: Maybe(LinearChildSizingFixed)
layout_linear_child :: proc(rule: LinearChildSizingFixed) {
	cache = rule
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
			v := rule.amount * ab.dpi
			r = {type = .Fit, constraints = {sizeMinMax = {v, v}}}
		case .Ratio:
			v := rule.amount
			r = {type = .Percent, constraints = {sizeMinMax = {v, v}}}
		case .Weight:
			v := rule.amount
			r = {type = .Grow, constraints = {sizeMinMax = {v, v}}}
	}
	return r
}

layout_container :: proc(children_layout: ChildrenLayout, maybe_tag:Maybe(string) = nil) {

	if tag, ok := maybe_tag.?; ok {
		clay._OpenElementWithId(clay.ID(tag))
	} else {
		clay._OpenElement()
	}

	direction: clay.LayoutDirection
	#partial switch c in children_layout {
		case Layout_Linear_Horizontal:
			direction = .LeftToRight
		case Layout_Linear_Vertical:
			direction = .TopToBottom
	}

	item_sizing := clay.Sizing {
		width = clay.SizingGrow(),
		height = clay.SizingFit(),
	}

	if rule, ok := cache.?; ok {
		item_sizing.width = convert_to_clay_rule(rule.width)
		item_sizing.height = convert_to_clay_rule(rule.height)
		//log.info(maybe_tag, item_sizing)
		cache = nil
	}

	clay.ConfigureOpenElement({
		layout = {
			layoutDirection = direction,
			sizing = item_sizing,
		}
	})
}

layout_close :: proc() {
	clay._CloseElement()
}


class_btn := style_class("Button")

text_config: ^clay.TextElementConfig


layout_button :: proc {
	layout_button_callback,
	layout_button_handler,
}

layout_button_callback :: proc(text: string, variant: ^StyleClass = nil, callback: ab.ButtonHandlerSimple) {
	info: ^ab.HandlerInfoSimple
	if callback != nil {
		info = new(ab.HandlerInfoSimple, context.temp_allocator)
		info.handler = _handle_proc_simple
		info.target = callback
	}
	layout_button_handler(text, variant, info)
}


_handle_proc_simple :: proc(userdata: ^ab.HandlerInfo) {
	data_simple := (^ab.HandlerInfoSimple)(userdata)
	data_simple.target()
}


layout_button_handler :: proc(text: string, variant: ^StyleClass = nil, info: ^ab.HandlerInfo = nil) {

	btn_style := get_current_style(&class_btn, ButtonStyle)

	style: ^BoxStyle
	// switch button state
	style = &btn_style.idle_box

	clay._OpenElement()

	ab.ui_add_button(text, info)
	if clay.Hovered() {
		style = &btn_style.hover_box
	}

	config_box_style(style^)
	
	text_style: ^TextStyle
	text_style = &btn_style.idle_text
	
	layout_text(text)

	layout_close() // box
}

config_box_style :: proc(style: BoxStyle) {

	switch s in style {
		case BoxStyleColored:
			config_box_colored(s)
		case BoxStyleTextured:
			config_box_textured(s)
	}
}

config_box_colored :: proc(style: BoxStyleColored) {


	item_sizing := clay.Sizing {
		width = clay.SizingFit(),
		height = clay.SizingFit(),
	}

	if rule, ok := cache.?; ok {
		item_sizing.width = convert_to_clay_rule(rule.width)
		item_sizing.height = convert_to_clay_rule(rule.height)
		//log.info(maybe_tag, item_sizing)
		cache = nil
	}

	clay.ConfigureOpenElement(
		ab.DPI(
			{
				layout = {
					padding = {
						u16(style.padding.left),
						u16(style.padding.right),
						u16(style.padding.top),
						u16(style.padding.bottom),
					},
					sizing = item_sizing,
				},
				backgroundColor = style.background,
				border = {
					color = style.border_color,
					width = {
						u16(style.border_width.left),
						u16(style.border_width.right),
						u16(style.border_width.top),
						u16(style.border_width.bottom),
						0,
					}
				},
				cornerRadius = transmute(clay.CornerRadius) style.corner_radii,
			}
		)
	)

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
}

layout_text :: proc {
	layout_text_const,
	layout_text_dynamic,
}

layout_textbox :: proc(text: string, variant: ^StyleClass = nil, info: ^ab.HandlerInfo = nil) {

	box_style := get_current_style(&class_btn, ButtonStyle)

	style: ^BoxStyle
	// switch button state
	style = &box_style.idle_box

	clay._OpenElement()

	ab.ui_add_button(text, info)
	if clay.Hovered() {
		style = &box_style.hover_box
	}

	config_box_style(style^)
	
	text_style: ^TextStyle
	text_style = &box_style.idle_text
	
	layout_text(text)

	layout_close() // box
}
