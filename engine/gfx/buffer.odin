package gfx

import SDL "vendor:sdl3"


draw_buffer :: proc(buffer: ^DrawBuffer, in_color: [4]f32) {

	fcolor := SDL.FColor{in_color[0], in_color[1], in_color[2], in_color[3]}

	//SDL.SetRenderTextureAddressMode(renderer, .CLAMP, .CLAMP)
	SDL.SetRenderTextureAddressMode(draw_context.renderer, .WRAP, .WRAP)

	indices: rawptr = nil
	if buffer.indices != nil && len(buffer.indices) > 0 {
		indices = &buffer.indices[0]
	}
	SDL.SetTextureColorModFloat(draw_context.helper, 1, 1, 1)
	SDL.SetTextureAlphaModFloat(draw_context.helper, 1)
	SDL.RenderGeometryRaw(
		draw_context.renderer,
		draw_context.helper, // texture
		&buffer.vertices[0][0],
		8, // verts + stride
		&fcolor,
		0, // color + stride
		&buffer.uvs[0][0],
		8, // uvs
		buffer.num_vertices,
		indices,
		buffer.num_indices,
		1,
	)
}


