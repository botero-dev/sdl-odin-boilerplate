package ui

import "base:runtime"
import "core:c"
import "core:log"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"


FontId :: distinct u16

NIL_FONT :: FontId(~u16(0))

FontData :: struct {
	font_io: ^SDL.IOStream,
	sizes:   map[u16]^TTF.Font,
}

loaded_fonts: u16 = 0
fonts: [dynamic]FontData
text_engine: ^TTF.TextEngine

default_font_id := NIL_FONT
symbol_font_id := NIL_FONT




load_font_io :: proc(io: ^SDL.IOStream) -> u16 {
	new_font := FontData {
		font_io = io,
	}
	loaded_font_id := loaded_fonts
	log.info("set font io:", loaded_font_id)
	append(&fonts, new_font)
	loaded_fonts += 1
	return loaded_font_id
}


get_font_with_size :: proc(font_id: FontId, size: u16) -> ^TTF.Font {
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

get_text_with_font_size :: proc(font_id: FontId, size: u16) -> ^TTF.Text {
	//log.info("get_text_with_size")
	font := get_font_with_size(font_id, size)
	if font == nil {
		return nil
	}
	if single_text == nil {
		single_text = TTF.CreateText(text_engine, font, "My Text", 0)
	}
	TTF.SetTextFont(single_text, font)
	return single_text
}


measure_text :: proc(text: string, font_id: FontId, font_size: u16) -> f32x2 {
	font := get_font_with_size(font_id, font_size)
	if font == nil {
		log.info("unable to calculate font size")
		return {}
	}
	size := [2]c.int{}
	TTF.GetStringSizeWrapped(font, cstring(raw_data(text)), len(text), 0, &size.x, &size.y)

	return {f32(size.x), f32(size.y)}
}

text_config_default: ^TextStyle

refresh_font_styles :: proc() {
	btn_style := get_current_style(&class_btn, ButtonStyle)
	btn_style.idle_text.font = default_font_id

	btn_icon_style := get_current_style(&class_btn_icon, ButtonStyle)
	btn_icon_style.idle_text.font = symbol_font_id
}