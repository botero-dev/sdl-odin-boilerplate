package gfx

import SDL "vendor:sdl3"

renderer: ^SDL.Renderer

win_size: [2]i32

init :: proc() {


	helper = SDL.CreateTexture(renderer, .RGBA32, .TARGET, 2, 2)
	SDL.SetRenderTarget(renderer, helper)
	SDL.SetRenderDrawColorFloat(renderer, 0, 0, 0, 0)
	SDL.RenderClear(renderer)

	SDL.SetRenderDrawColorFloat(renderer, 1, 1, 1, 0)
	SDL.RenderPoint(renderer, 0, 0)
	SDL.RenderPoint(renderer, 0, 1)
	SDL.RenderPoint(renderer, 1, 0)

	SDL.SetRenderDrawColorFloat(renderer, 1, 1, 1, 1)
	SDL.RenderPoint(renderer, 1, 1)

	SDL.SetRenderTarget(renderer, nil)


	// for drawing cheap lines
	SDL.SetTextureScaleMode(helper, .PIXELART)
	//SDL.SetTextureScaleMode(helper, .LINEAR)
	SDL.SetTextureBlendMode(helper, {.BLEND})
}
