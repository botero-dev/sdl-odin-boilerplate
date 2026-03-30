
package engine

import SDL "vendor:sdl3"

import "core:fmt"
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

	@(export)
	main_start :: proc "c" () {
		sdl_app_init(nil, 0, nil)
	}

	@(export)
	web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
		SDL.SetWindowSize(window, w, h)
	}

	@(export)
	main_update :: proc "c" () -> bool {
		event: SDL.Event
		context = ctx
		for (SDL.PollEvent(&event)) {
			sdl_event(nil, &event)
		}
		return sdl_iterate(nil) == .CONTINUE
	}

	@(export)
	main_end :: proc "c" () {
		sdl_quit(nil, {})
	}
} else when ODIN_PLATFORM_SUBTARGET == .Android {
	// entry point for .so load in android
	@(export)
	android_main :: proc "c" (appstate: rawptr) {
		context = runtime.default_context()
		context.logger = runtime.Logger {
			procedure = sdl_log_proc,
		}
		log.info("android_main")
	}

	@(export)
	SDL_main :: proc "c" (argc: i32, argv: [^]cstring) -> i32 {
		context = runtime.default_context()
		context.logger = runtime.Logger {
			procedure = sdl_log_proc,
		}
		log.info("android SDL_main")
		sdl_app_main()
		return 0
	}

} else {

	// standard entry point for desktop targets
	main :: proc() {
		context.logger = log.create_console_logger()
		//sdl_app_main()
	}

}


/*
Logger_Proc :: #type proc(data: rawptr, level: Level, text: string, options: Options, location := #caller_location);
*/

sdl_log_proc :: proc(
	data: rawptr,
	level: runtime.Logger_Level,
	text: string,
	options: runtime.Logger_Options,
	location := #caller_location,
) {
	temporary := fmt.ctprintf("[%s] %s", level, text)
	SDL.Log("%s", temporary)
}



callback_init: proc()
callback_iterate: proc()
callback_quit: proc()


app_init :: proc(handler_init: proc(), handler_iterate: proc(), handler_quit: proc() = nil) {
	callback_init = handler_init
	callback_iterate = handler_iterate
	callback_quit = handler_quit

	if context.logger.procedure == runtime.default_logger_proc {
		context.logger = runtime.Logger {
			procedure = sdl_log_proc,
		}
	}
	ctx = context
	log.info("sdl_app_main()")


	//args := os.args
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		// we don't use this as we call the callbacks directly
	} else {
		SDL.EnterAppMainCallbacks(
			0,
			nil,
			sdl_init,
			sdl_iterate,
			sdl_event,
			sdl_quit,
		)
	}
}

main_thread: SDL.ThreadID

app_status: SDL.AppResult = .CONTINUE

sdl_init :: proc "c" (appstate: ^rawptr, argc: i32, argv: [^]cstring) -> SDL.AppResult {
	context = ctx
	main_thread = SDL.GetCurrentThreadID()

	app_event_init()
	load_queue = SDL.CreateAsyncIOQueue()

	callback_init()
	return app_status
}

sdl_event :: proc "c" (appstate: rawptr, event: ^SDL.Event) -> SDL.AppResult {
	context = ctx
	return app_handle_event(event)
}

sdl_iterate :: proc "c" (appstate: rawptr) -> SDL.AppResult {
	context = ctx
	callback_iterate()
	return app_status
}

sdl_quit :: proc "c" (appstate: rawptr, result: SDL.AppResult) {
	context = ctx
	log.info("quit")
	if callback_quit != nil {
		callback_quit()
	}
}

get_global_context :: proc "c" () -> runtime.Context {
	return ctx
}
