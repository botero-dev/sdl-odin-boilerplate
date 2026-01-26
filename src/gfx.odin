
package main

import SDL "vendor:sdl3"

import "core:log"
import "core:math/linalg"

helper: ^SDL.Texture

gfx_init :: proc () {
	helper = SDL.CreateTexture(renderer, .RGBA32, .TARGET, 2, 2)
	SDL.SetRenderTarget(renderer, helper)
	SDL.SetRenderDrawColor(renderer, 0, 0, 0, 0)
	SDL.RenderClear(renderer)
	SDL.SetRenderDrawColor(renderer, 255, 255, 255, 255)
	SDL.RenderPoint(renderer, 1, 1)
	SDL.SetTextureScaleMode(helper, .LINEAR)
	SDL.SetTextureBlendMode(helper, {.BLEND_PREMULTIPLIED})
}


draw_line :: proc(renderer: ^SDL.Renderer, start: vec2, end: vec2, width: f32) {

	dir := linalg.normalize(end-start)
	dir_side := vec2{dir.y, -dir.x}

	PAD :: 2
	side := dir_side * (width * 0.5 + PAD + 1)
	vstart := start + vec2{0.5, 0.5}
	vend := end + vec2{0.5, 0.5}
	vertices := []vec2{
		vstart - side,
		vstart,
		vstart + side,
		vend - side,
		vend,
		vend + side,
	}

	TEX_SIZE :: 2
	ZERO_PIX_CLAMP := vec2{0.5, 1.5} / TEX_SIZE
	PIXEL_X := vec2{1, 0} / TEX_SIZE
	PIXEL_Y := vec2{1, 0} / TEX_SIZE
	uvs := []vec2{
		ZERO_PIX_CLAMP - (PAD*PIXEL_Y),
		ZERO_PIX_CLAMP + (PIXEL_Y * width * 0.5),
		ZERO_PIX_CLAMP - (PAD*PIXEL_Y),
		ZERO_PIX_CLAMP - (PAD*PIXEL_Y),
		ZERO_PIX_CLAMP + (PIXEL_Y * width * 0.5),
		ZERO_PIX_CLAMP - (PAD*PIXEL_Y),
	}
	log.info("verts: ", vertices)
	log.info("uvs:   ", uvs)
	indices := []u8{
		0, 1, 3, 1, 3, 4, 1, 2, 4, 2, 4, 5
	}
	color := SDL.FColor{1, 1, 1, 1}

	SDL.SetRenderTextureAddressMode(renderer, .CLAMP, .CLAMP)

	SDL.RenderGeometryRaw(
		renderer, helper,
			&vertices[0][0], 8,
			&color, 0,
			&uvs[0][0], 8,
		i32(len(vertices)),
			&indices[0],
		i32(len(indices)),
		1
	)

	SDL.SetRenderDrawColor(renderer, 255, 0, 0, 255)
	SDL.RenderPoint(renderer, start.x, start.y)
	SDL.RenderPoint(renderer, end.x, end.y)
}
