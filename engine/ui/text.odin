package ui

import "core:mem"

TextModifier :: enum(u16) {
	Bold,
	Italics,
	Underline,
	Strikethrough,
	SmallCaps,
	AllCaps,
}

TextModifierFlags :: bit_set[TextModifier]

TextStyle :: struct {
	//using config: clay.TextStyle
	font: FontId,
	size: u16,
	color: Color32,
	weight: u16,
	modifier: TextModifierFlags, 
}

// todo: figure out how to deal with i18n

layout_text :: proc(
    text: string,
	style: ^StyleClass = nil, 
	font: Maybe(FontId) = nil,
	size: Maybe(u16) = nil,
	color: Maybe(Color32) = nil,
	weight: Maybe(u16) = nil,
	modifier: Maybe(TextModifierFlags) = nil, 
) {
	result: WithOverrides(TextStyle)
    any_override := false

    if font != nil {
        any_override = true
    }
    if size != nil {
        any_override = true
    }
    if color != nil {
        any_override = true
    }
    if weight != nil {
        any_override = true
    }
    if modifier != nil {
        any_override = true
    }

    style_ptr: ^TextStyle = text_config_default
    if style != nil {
        style_ptr = get_current_style(style, TextStyle)
    }

    if any_override {
        base := style_ptr
        allocator := mem.arena_allocator(&layout_state.computed_arena)
        style_ptr = new(TextStyle, allocator)
        style_ptr^ = base^

        if font != nil {
            style_ptr.font = font.?
        }
        if size != nil {
            style_ptr.size = size.?
        }
        if color != nil {
            style_ptr.color = color.?
        }
        if weight != nil {
            style_ptr.weight = weight.?
        }
        if modifier != nil {
            style_ptr.modifier = modifier.?
        }
    }

    _layout_text(text, style_ptr)
}

