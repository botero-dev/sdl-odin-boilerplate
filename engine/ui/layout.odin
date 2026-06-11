package ui

import "core:log"

import clay "../clay-odin"
import ab ".."


render_commands: clay.ClayArray(clay.RenderCommand)

text_config_default: ^clay.TextElementConfig

layout_stack: [dynamic]ChildrenLayout


layout_begin :: proc() {

	if cache_overlay != nil {
		log.info("overlay layout hint:", cache_overlay.?, "wasn't consumed in previous frame")
		cache_overlay = nil
	}
	
	if cache_linear != nil {
		log.info("linear layout hint:", cache_linear.?, "wasn't consumed in previous frame")
		cache_linear = nil
	}
	

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

	append(&layout_stack, Layout_Overlay{})
}

layout_end :: proc() {
	pop(&layout_stack)
	if len(layout_stack) != 0 {
		log.error("layout_stack is not empty when finishing drawing.")
		log.error(layout_stack)
	}
	clear(&layout_stack)

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
	// container state
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


cache_overlay: Maybe(OverlayChildSizing)
cache_linear: Maybe(LinearChildSizingFixed)

layout_overlay_child :: proc(rule: OverlayChildSizing) {
	if cache_linear != nil {
		log.error("unconsumed layout hint '", cache_linear, "' before pushing '", rule, "'")
	}

	current := layout_stack[len(layout_stack)-1]
	#partial switch v in current {
		case Layout_Overlay:
			break;
		case:
			//log.error("bad rule:", rule, " for current parent:", current)
	}

	cache_overlay = rule
}


layout_linear_child :: proc(rule: LinearChildSizingFixed) {
	if cache_linear != nil {
		log.error("unconsumed layout hint '", cache_linear, "' before pushing '", rule, "'")
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

	cache_linear = rule
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

layout_container :: proc(children_layout: ChildrenLayout, style: ^StyleClass = nil,  maybe_tag:Maybe(string) = nil) {
	if tag, ok := maybe_tag.?; ok {
		clay._OpenElementWithId(clay.ID(tag))
	} else {
		clay._OpenElement()
	}

	elem := clay.ElementDeclaration{}
	apply_decl(&elem, children_layout)

	if style != nil {
		box_style := get_current_style(&style_tab_bar, BoxStyleColored)
		apply_style_box_colored(&elem, box_style^)
	}

	clay.ConfigureOpenElement(elem)

	append(&layout_stack, children_layout)
}

DEBUG := false

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


	item_sizing := clay.Sizing {
		width = clay.SizingGrow(),
		height = clay.SizingFit(),
	}

	item_floating := clay.FloatingElementConfig {}

	current := layout_stack[len(layout_stack)-1]
	switch layout in current {
		case Layout_Overlay:
			item_floating.attachTo = .Parent
			rule := OverlayChildSizing {}

			if DEBUG {
				log.info("overlay rule before:", rule)
			}
			
			if cached_rule, ok := cache_overlay.?; ok {
				rule = cached_rule
				cache_overlay = nil // is this really necessary/desired?
			}
			if DEBUG {
				log.info("overlay rule:", rule)
				log.info("cache:", cache_overlay)
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
		
		case Layout_Linear_Horizontal:
			rule := LinearChildSizingFixed {}
			if in_rule, ok := cache_linear.?; ok {
				rule = in_rule
				cache_linear = nil
			}
			item_sizing.width = convert_to_clay_rule(rule.width)
			item_sizing.height = convert_to_clay_rule(rule.height)
			//log.info(maybe_tag, item_sizing)
		case Layout_Linear_Vertical:
			rule := LinearChildSizingFixed {}
			if in_rule, ok := cache_linear.?; ok {
				rule = in_rule
				cache_linear = nil
			}
			item_sizing.width = convert_to_clay_rule(rule.width)
			item_sizing.height = convert_to_clay_rule(rule.height)
			//log.info(maybe_tag, item_sizing)
	}

	elem.layout.sizing = item_sizing
	elem.floating = item_floating
}

layout_close :: proc() {
	pop(&layout_stack)
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

	style_class := variant
	if style_class == nil {
		style_class = &class_btn
	}
	btn_style := get_current_style(style_class, ButtonStyle)

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
			u16(style.border_width.left),
			u16(style.border_width.right),
			u16(style.border_width.top),
			u16(style.border_width.bottom),
			0,
		}	
	}
	elem.cornerRadius = transmute(clay.CornerRadius) style.corner_radii
}
	

config_box_colored :: proc(style: BoxStyleColored) {

	elem := clay.ElementDeclaration {
		layout = {
			padding = {
				u16(style.padding.left),
				u16(style.padding.right),
				u16(style.padding.top),
				u16(style.padding.bottom),
			},
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

	apply_decl(&elem, Layout_Linear_Horizontal{})

	clay.ConfigureOpenElement(ab.DPI(elem))

	append(&layout_stack, Layout_Linear_Horizontal{})
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
