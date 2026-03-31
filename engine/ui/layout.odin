package ui

import clay "../clay-odin"
import ab ".."


render_commands: clay.ClayArray(clay.RenderCommand)

layout_begin :: proc() {
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
	along: Sizing,
	across: Sizing,
}

layout_container :: proc(children_layout: ChildrenLayout) {
	clay._OpenElement()

	direction: clay.LayoutDirection
	#partial switch c in children_layout {
		case Layout_Linear_Horizontal:
			direction = .LeftToRight
		case Layout_Linear_Vertical:
			direction = .TopToBottom
	}

	clay.ConfigureOpenElement({
		layout = {
			layoutDirection = direction,
			sizing = {
				width = clay.SizingGrow(),
				height = clay.SizingFit(),
			},
		}
	})
}

layout_close :: proc() {
	clay._CloseElement()
}


class_btn := style_class("Button")

text_config: ^clay.TextElementConfig

layout_button :: proc(text: string, variant: ^StyleClass = nil) {

	btn_style := get_current_style(&class_btn, ButtonStyle)

	style: ^BoxStyle
	// switch button state
	style = &btn_style.idle_box

	layout_box_style(style^)
	
	text_style: ^TextStyle
	text_style = &btn_style.idle_text
	clay.TextDynamic(text, text_style)

	layout_close() // box
}

layout_box_style :: proc(style: BoxStyle) {
	switch s in style {
		case BoxStyleColored:
			layout_box_colored(s)
		case BoxStyleTextured:
			layout_box_textured(s)
	}
}

layout_box_colored :: proc(style: BoxStyleColored) {

	clay._OpenElement()

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

layout_box_textured :: proc(style: BoxStyleTextured) {

}