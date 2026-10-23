package gfx


import SDL "vendor:sdl3"


DrawContext :: struct {
    renderer: ^SDL.Renderer,
    helper: ^SDL.Texture,
}

_renderer: ^SDL.Renderer
_helper: ^SDL.Texture

draw_context: DrawContext


drawcontext_create :: proc(renderer: ^SDL.Renderer) -> DrawContext {

    ctx := DrawContext {}

	ctx.renderer = renderer
	SDL.SetRenderVSync(renderer, 1)
	
	ctx.helper = SDL.CreateTexture(renderer, .RGBA32, .TARGET, 2, 2)
	SDL.SetRenderTarget(renderer, ctx.helper)
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
	SDL.SetTextureScaleMode(ctx.helper, .PIXELART)
	//SDL.SetTextureScaleMode(helper, .LINEAR)
	SDL.SetTextureBlendMode(ctx.helper, {.BLEND})

    return ctx
}

drawcontext_activate :: proc(ctx: DrawContext) {
    draw_context = ctx
}