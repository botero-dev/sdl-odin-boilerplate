package sdl3

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	@(export) foreign import lib { "libSDL3.o" }
} else when ODIN_OS == .Windows {
	@(export) foreign import lib { "SDL3.lib" }
} else {
	@(export) foreign import lib { "system:SDL3" }
}