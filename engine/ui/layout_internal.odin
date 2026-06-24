package ui

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

_layout_begin :: proc(in_scale_factor: f32) {
    scale_factor = in_scale_factor
   	clay.BeginLayout()

}


_layout_end :: proc() {
	render_commands = clay.EndLayout()
}


clay_elem: clay.ElementDeclaration
LayoutItem :: struct {
    
}

_layout_create :: proc(child_layout: ChildrenLayout) {
   	clay._OpenElement()
	clay_elem = {}

    apply_decl(&clay_elem, child_layout)
	append(&layout_stack, child_layout)
}

_layout_open :: proc() {
    clay.ConfigureOpenElement(DPI(clay_elem))
}

_layout_close :: proc() {
	pop(&layout_stack)
	clay._CloseElement()
}

LayoutStateItem :: struct {
    computed_rect: Rect
}

// will hold last computed layout state. It will also hold data needed to resolve mouse events.
// It will take into account themes data like padding as it matters to layout. but other things like colors will be kept as pointers to point to them when drawing

LayoutState :: struct {
    rect: Rect
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
