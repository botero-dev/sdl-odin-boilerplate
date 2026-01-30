
package main

import SDL "vendor:sdl3"

import "core:fmt"
import "core:c"
import "core:strings"
import "core:log"

import "base:runtime"

ctx: runtime.Context

///////////////////////////////////////////////////////
// desktop/wasm handling

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {

	main :: proc() {
		context.logger = log.create_console_logger()
		ctx = context
		log.info("wasm main")
	}

	@export
	main_start :: proc "c" () {
		sdl_app_init(nil, 0, nil)
	}

	@export
	web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
		SDL.SetWindowSize(window, w, h)
	}

	@export
	main_update :: proc "c" () -> bool {
		event: SDL.Event
		context = ctx
		for (SDL.PollEvent(&event)) {
			sdl_app_event(nil, &event)
		}
		return sdl_app_iterate(nil) == .CONTINUE
	}

	@export
	main_end :: proc "c" () {
		sdl_app_quit(nil, {})
	}
} else when ODIN_PLATFORM_SUBTARGET == .Android {
	// entry point for .so load in android
	@(export)
	android_main :: proc "c" (appstate: rawptr) {
		context = runtime.default_context()
		context.logger = runtime.Logger {
			procedure = sdl_log_proc
		}
		log.info("android_main")
	}

	@(export)
	SDL_main :: proc "c" (argc: c.int, argv: [^]cstring) -> c.int {
		context = runtime.default_context()
		sdl_app_main()
		return 0;
	}

} else {

	// standard entry point for desktop targets
	main :: proc() {
		context.logger = log.create_console_logger()
		sdl_app_main()
	}

}


/*
Logger_Proc :: #type proc(data: rawptr, level: Level, text: string, options: Options, location := #caller_location);
*/

sdl_log_proc :: proc(data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location) {
	temporary := fmt.ctprintf("[%s] %s", level, text)
	SDL.Log("%s", temporary)
}

sdl_app_main :: proc () {
	context.logger = runtime.Logger {
		procedure = sdl_log_proc
	}
	ctx = context
	log.info("sdl_app_main()")


    //args := os.args
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		// we don't use this as we call the callbacks directly
	} else {
        SDL.EnterAppMainCallbacks(0, nil, sdl_app_init, sdl_app_iterate, sdl_app_event, sdl_app_quit)
    }
}

sdl_app_init :: proc "c" (appstate: ^rawptr, argc: i32, argv: [^]cstring) -> SDL.AppResult {
	context = ctx
	return app_init(appstate, argc, argv)
}

sdl_app_event :: proc "c" (appstate: rawptr, event: ^SDL.Event) -> SDL.AppResult {
	context = ctx
	return app_event(appstate, event)
}

sdl_app_iterate :: proc "c" (appstate: rawptr) -> SDL.AppResult {
	context = ctx
	return app_iterate(appstate)
}

sdl_app_quit :: proc "c" (appstate: rawptr, result: SDL.AppResult) {
	context = ctx
	log.info("quit")
}

get_global_context :: proc "c" () -> runtime.Context {
	return ctx
}
