package gfx

import SDL "vendor:sdl3"


draw_buffer :: proc(renderer: ^SDL.Renderer, buffer: ^DrawBuffer, in_color: [4]f32) {

	fcolor := SDL.FColor{in_color[0], in_color[1], in_color[2], in_color[3]}

	//SDL.SetRenderTextureAddressMode(renderer, .CLAMP, .CLAMP)
	SDL.SetRenderTextureAddressMode(renderer, .WRAP, .WRAP)

	indices: rawptr = nil
	if buffer.indices != nil && len(buffer.indices) > 0 {
		indices = &buffer.indices[0]
	}
	SDL.RenderGeometryRaw(
		renderer,
		helper, // texture
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


