
package engine

import "engine:fs"
import SDL "vendor:sdl3"

import "core:strings"
import "core:log"
import "core:c"
import "core:fmt"

import "base:runtime"


ctx: runtime.Context

///////////////////////////////////////////////////////
// desktop/wasm handling

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {

	@(export)
	main_start :: proc "c" () {
		context = runtime.default_context()
		fmt.println("wasm main_start")
		
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

	// SDL's Java layer calls SDL_main() from libmain.so to drive the app.
	// It must be exported so nativeRunMain can find it, otherwise the
	// activity is torn down with "Couldn't find function SDL_main".
	// app_init() (run at library load from the .init thread) has already
	// registered the app callbacks by the time this runs.
	@(export)
	SDL_main :: proc "c" (argc: i32, argv: [^]cstring) -> i32 {
		context = runtime.default_context()
		context.logger = runtime.Logger {
			procedure = sdl_log_proc,
		}
		ctx = context
		log.info("android SDL_main")
		return i32(SDL.EnterAppMainCallbacks(0, nil, sdl_init, sdl_iterate, sdl_event, sdl_quit))
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
	priority := SDL.LogPriority.INVALID

	switch level {
	case .Debug:
		priority = SDL.LogPriority.DEBUG
	case .Info:
		priority = SDL.LogPriority.INFO
	case .Warning:
		priority = SDL.LogPriority.WARN
	case .Error:
		priority = SDL.LogPriority.ERROR
	case .Fatal:
		priority = SDL.LogPriority.CRITICAL
	}

	temporary := strings.clone_to_cstring(text, context.temp_allocator)
	SDL.LogMessage(i32(SDL.LogCategory.APPLICATION), priority, "%s", temporary)
}


callback_init: proc()
callback_iterate: proc()
callback_quit: proc()

AppMetadata :: struct {
	name: cstring,
	version: cstring,
	identifier: cstring,
}


app_init :: proc(metadata: Maybe(AppMetadata), handler_init: proc(), handler_iterate: proc(), handler_quit: proc() = nil) {

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {} else {
	back_register_segfault_handler()
	context.assertion_failure_proc = back_get_assertion_failure_proc()
}

	if meta, has_meta := metadata.?; has_meta {
		_ = SDL.SetAppMetadata(meta.name, meta.version, meta.identifier)
	}

	callback_init = handler_init
	callback_iterate = handler_iterate
	callback_quit = handler_quit

	// use console logger
	context.logger = log.create_console_logger()

	// use SDL logger
	// context.logger = runtime.Logger { procedure = sdl_log_proc }

	ctx = context
	log.info("app_init")


	// On Android, app_init is invoked from the .init/constructor thread at
	// library load (before SDL's Java layer runs), so we only register the
	// app callbacks here; SDL_main() (exported above) runs the app loop on
	// the SDL thread via EnterAppMainCallbacks. Running it here would
	// conflict with SDL's Java-driven SDL_main.
	when ODIN_PLATFORM_SUBTARGET != .Android {
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
	log.debug("sdl_init")

	main_thread = SDL.GetCurrentThreadID()

	app_event_init()

	// SDL_Init must run before SDL_CreateAsyncIOQueue: the queue's worker
	// thread does JNI/app-metadata lookups (SDL_GetExeName) that require
	// SDL's platform init, which is only set up by SDL_Init. On Android this
	// otherwise crashes with "CallStaticObjectMethod received NULL jclass".
	if !SDL.Init({.VIDEO}) {
		log.error("SDL.Init failed")
		return .FAILURE
	}

	fs.init()
	


	when ODIN_OS == .Linux && !(ODIN_PLATFORM_SUBTARGET == .Android) {
		SDL.SetHint(SDL.HINT_VIDEO_DRIVER, "wayland,x11") // prefer wayland if available
		SDL.SetHint(SDL.HINT_PEN_MOUSE_EVENTS, "0")
		SDL.SetHint(SDL.HINT_PEN_TOUCH_EVENTS, "0")
	}


	callback_init()
	return app_status
}

sdl_event :: proc "c" (appstate: rawptr, event: ^SDL.Event) -> SDL.AppResult {
	context = ctx
	return app_handle_event(event)
}

sdl_iterate :: proc "c" (appstate: rawptr) -> SDL.AppResult {
	context = ctx

	fs.idle_process_async()
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
