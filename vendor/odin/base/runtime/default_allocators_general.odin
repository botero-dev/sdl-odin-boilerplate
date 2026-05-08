package runtime

USE_EMSCRIPTEN_ALLOCATOR :: #config(ODIN_DEFAULT_TO_EMSCRIPTEN_ALLOCATOR, false)

when USE_EMSCRIPTEN_ALLOCATOR {
	default_allocator :: emscripten_allocator
	default_allocator_proc :: emscripten_allocator_proc
} else when ODIN_DEFAULT_TO_NIL_ALLOCATOR {
	default_allocator_proc :: nil_allocator_proc
	default_allocator :: nil_allocator
} else when ODIN_DEFAULT_TO_PANIC_ALLOCATOR {
	default_allocator_proc :: panic_allocator_proc
	default_allocator :: panic_allocator
} else when ODIN_OS != .Orca && (ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32) {
	default_allocator :: default_wasm_allocator
	default_allocator_proc :: wasm_allocator_proc
} else {
	default_allocator :: heap_allocator
	default_allocator_proc :: heap_allocator_proc
}
