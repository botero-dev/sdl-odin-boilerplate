
package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:c"
import "core:strings"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import clay "clay-odin"

vec2 :: [2]f32


dpi := f32(1.0)
DPI_set :: proc(new_dpi: f32) {
	dpi = new_dpi
	log.info("set dpi to:", dpi)
}

DPI_mult :: proc(value: f32) -> f32 {
	return value * dpi
}

border_policy :: proc (border: $T) -> u16 {
	return u16(math.round(f32(border) * dpi)) // could also be ceil or floor
}

DPI_ElementDeclaration :: proc (decl: clay.ElementDeclaration) -> clay.ElementDeclaration {
	result := decl
	result.cornerRadius = DPI_CornerRadius(decl.cornerRadius)
	result.border.width = DPI_BorderWidth(result.border.width)
	result.layout.padding = DPI_Padding(result.layout.padding)
	result.layout.childGap = border_policy(result.layout.childGap)
	result.floating.offset.x *= dpi
	result.floating.offset.y *= dpi

	if result.layout.sizing.width.type == .Fixed {
		result.layout.sizing.width.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.width.constraints.sizeMinMax.max *= dpi
	}
	if result.layout.sizing.height.type == .Fixed {
		result.layout.sizing.height.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.height.constraints.sizeMinMax.max *= dpi
	}

	return result
}

DPI :: DPI_ElementDeclaration

DPI_BorderWidth :: proc (input: clay.BorderWidth) -> clay.BorderWidth {
	return clay.BorderWidth {
		border_policy(input.left),
		border_policy(input.right),
		border_policy(input.top),
		border_policy(input.bottom),
		border_policy(input.betweenChildren),
	}
}

DPI_CornerRadius :: proc (radii: clay.CornerRadius) -> clay.CornerRadius {
	return clay.CornerRadius {
		dpi * (radii.topLeft),
		dpi * (radii.topRight),
		dpi * (radii.bottomLeft),
		dpi * (radii.bottomRight),
	}
}

DPI_Padding :: proc (padding: clay.Padding) -> clay.Padding {
	return clay.Padding {
		border_policy(padding.left),
		border_policy(padding.right),
		border_policy(padding.top),
		border_policy(padding.bottom),
	}
}

print_render_commands: bool

render_layout :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for idx in 0..<i32(render_commands.length) {
        render_command := clay.RenderCommandArray_Get(render_commands, idx)
        switch render_command.commandType {
        case .Rectangle:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.rectangle)
			}

            rect := render_command.renderData.rectangle
			box := render_command.boundingBox
			corners := rect.cornerRadius
			if corners == {0, 0, 0, 0} {
				//fmt.println(render_command)
				color := rect.backgroundColor
				SDL.SetRenderDrawColorFloat(renderer, color[0], color[1], color[2], color[3])
				SDL.SetRenderDrawBlendMode(renderer, {.BLEND})
				rect2 := SDL.FRect{
					w = box.width,
					h = box.height,
					x = box.x,
					y = box.y,
				}
				SDL.RenderFillRect(renderer, &rect2)
			} else {
				draw_box_filled(box, rect)
			}

		case .Border:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.border)
			}

			border := render_command.renderData.border
            draw_box_border(render_command.boundingBox, border)


		case .Text:
            //fmt.println(render_command)
            box := render_command.boundingBox
            text_data := render_command.renderData.text
            string_slice := text_data.stringContents
            color := text_data.textColor
			if print_render_commands {
				str_to_draw := strings.string_from_ptr(string_slice.chars, int(string_slice.length))
				log.info("cmd:", idx, render_command, render_command.renderData.text)
				log.info("text:", str_to_draw)
			}


			text := get_text_with_font_size(text_data.fontId, text_data.fontSize)

			if text != nil {
				TTF.SetTextColor(text, u8(color[0]*255), u8(color[1]*255), u8(color[2]*255), u8(color[3]*255))
                TTF.SetTextString(text, cstring(string_slice.chars), uint(string_slice.length))
                TTF.SetTextWrapWidth(text, 0)
                TTF.DrawRendererText(text, math.round(box.x), math.round(box.y))
            }

		case .Image:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.image)
			}

			image := render_command.renderData.image
            color := image.backgroundColor

			tex := (^SDL.Texture)(image.imageData)
            SDL.SetTextureColorModFloat(tex, color[0], color[1], color[2])
			SDL.SetTextureAlphaModFloat(tex, color[3])
			SDL.SetTextureBlendMode(tex, {.BLEND})

            box := render_command.boundingBox
            rect2 := SDL.FRect{
                w = box.width,
                h = box.height,
                x = box.x,
                y = box.y,
            }
            SDL.RenderTexture(renderer, tex, nil, &rect2)

			corners := image.cornerRadius
			if corners != {0, 0, 0, 0} {
				log.info("image unhandled case!")
			}
		case .ScissorStart:
			if print_render_commands {
				log.info("cmd:", idx, render_command)
			}
			bbox := render_command.boundingBox
			clip_rect := SDL.Rect {i32(bbox.x), i32(bbox.y), i32(bbox.width), i32(bbox.height)}
            SDL.SetRenderClipRect(renderer, &clip_rect);
		case .ScissorEnd:
			if print_render_commands {
				log.info("cmd:", idx, render_command)
			}
            SDL.SetRenderClipRect(renderer, nil);
		case .None:
			fmt.println("unhandled render command type: None", render_command.commandType, render_command)
		case .Custom:
			fmt.println("unhandled render command type: Custom", render_command.commandType, render_command)

        }

    }
}


FontData :: struct {
	font_io: ^SDL.IOStream,
	sizes: map[u16]^TTF.Font,
}

loaded_fonts: u16 = 0 // we reserve fontid=0 for null font
fonts: [dynamic]FontData

load_font_io :: proc(io: ^SDL.IOStream) -> u16 {
	new_font := FontData {
		font_io = io
	}
	loaded_font_id := loaded_fonts
	log.info("set font io:", loaded_font_id)
	append(&fonts, new_font)
	loaded_fonts += 1
	return loaded_font_id
}

// TextElementConfig :: struct {
// 	userData:           rawptr,
// 	textColor:          Color,
// 	fontId:             u16,
// 	fontSize:           u16,
// 	letterSpacing:      u16,
// 	lineHeight:         u16,
// 	wrapMode:           TextWrapMode,
// 	textAlignment:      TextAlignment,
// }

// StringSlice :: struct {
// 	length: c.int32_t,
// 	chars:  [^]c.char,
// 	baseChars:  [^]c.char,
// }


clay_measure_text :: proc "c" (
    text: clay.StringSlice,
    config: ^clay.TextElementConfig,
    userData: rawptr,
) -> clay.Dimensions {
	context = ctx
	font := get_font_with_size(config.fontId, config.fontSize)
	if font == nil {
		log.info("unable to calculate font size")
		return {}
	}
	size := [2]c.int{}
	success := TTF.GetStringSize(font, cstring(text.chars), uint(text.length), &size.x, &size.y)
    return {
        width = f32(size.x),
        height = f32(size.y),
    }
}

NIL_FONT :: ~u16(0)

get_font_with_size :: proc(font_id: u16, size: u16) -> ^TTF.Font {
	if font_id == NIL_FONT {
		return nil
	}
	if int(font_id) >= len(fonts) {
		log.info("invalid font id, for null font use NIL_FONT")
		return nil
	}
	font := &fonts[font_id]
	font_size, ok := font.sizes[size]
	if !ok {
		font_size = TTF.OpenFontIO(font.font_io, false, f32(size))
		font.sizes[size] = font_size
	}
	return font_size
}


// single text object gets reused
single_text: ^TTF.Text

get_text_with_font_size :: proc(font_id: u16, size: u16) -> ^TTF.Text {
	//log.info("get_text_with_size")
	font := get_font_with_size(font_id, size)
	if font == nil {
		return nil
	}
	if single_text == nil {
		single_text = TTF.CreateText(engine, font, "My Text", 0)
	}
	TTF.SetTextFont(single_text, font)
	return single_text
}

nav_left: MappingIndex
nav_right: MappingIndex
nav_up: MappingIndex
nav_down: MappingIndex

// tab and shift-tab
nav_next: MappingIndex
nav_previous: MappingIndex

// select may be spacebar, where in a list may toggle mark, where enter key
// could be confirm selection
nav_select: MappingIndex
nav_confirm: MappingIndex
nav_cancel: MappingIndex


ui_init :: proc() {
	nav_left = create_keyboard_mapping(.LEFT)
	nav_right = create_keyboard_mapping(.RIGHT)
	nav_up = create_keyboard_mapping(.UP)
	nav_down = create_keyboard_mapping(.DOWN)

	nav_next = create_keyboard_mapping(.TAB)
	nav_previous = create_keyboard_mapping(.TAB) // TODO: use shift+tab

	nav_select = create_keyboard_mapping(.SPACE)
	nav_confirm = create_keyboard_mapping(.RETURN)
	nav_cancel = create_keyboard_mapping(.ESCAPE)

}


NavigationDirection :: enum {
	Horizontal, // left/right
	Vertical, // up/down
	Logical, // previous/next
	User, // L1/R1 or some user bindings
}

NavigationItem :: struct {
	id: i32,
	label: string,
	handler: ^HandlerInfo,
}

NavigationScope :: struct {
	direction: NavigationDirection,
	reverse: bool, // why would you?
	wrap: bool,
	contents: [dynamic]NavigationItem,
	current: i32
}

navigation_scope_stack: [dynamic]NavigationScope

navigation_scope: NavigationScope

nav_add_item :: proc(label: string, handler: ^HandlerInfo) -> bool {
	id := i32(len(navigation_scope.contents))
	nav_item := NavigationItem {
		id, label, handler,
	}
	append(&navigation_scope.contents, nav_item)
	focused := navigation_scope.current == id

	return focused
}

nav_handle_input :: proc(event: ^Event) {
	num_items := i32(len(navigation_scope.contents))
	if num_items == 0 {
		return
	}
	if pressed, matches := match_mapping_button(event, nav_left); matches {
		if pressed {
			event.handled = true
			navigation_scope.current -= 1
		}
	}
	if pressed, matches := match_mapping_button(event, nav_right); matches {
		if pressed {
			event.handled = true
			navigation_scope.current += 1
		}
	}
	if navigation_scope.current < 0 {
		if navigation_scope.wrap {
			navigation_scope.current = num_items - 1
		} else {
			navigation_scope.current = 0
		}
	} else if navigation_scope.current >= num_items {
		if navigation_scope.wrap {
			navigation_scope.current = 0
		} else {
			navigation_scope.current = num_items - 1
		}
	}

	if pressed, matches := match_mapping_button(event, nav_confirm); matches {
		if pressed {
			nav_item := navigation_scope.contents[navigation_scope.current]
			nav_item.handler.handler(nav_item.handler.data)
		}
	}
}
