package main

import "emscripten"
import SDL "vendor:sdl3"

import "core:fmt"
import "core:strings"
import "core:log"

import "base:runtime"


RequestResult :: struct {
	success: bool,
	bytes: []byte,
	user_data: rawptr,
}

RequestHandler :: struct {
	ctx: runtime.Context,
	user_handler: proc(result: RequestResult),
	user_data: rawptr,
}


// async on web, synchronous on desktop
request_data :: proc (url: cstring, user_data: rawptr, callback: proc(result: RequestResult)) {

	log.info("request_data", url)
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		fetch_attr := emscripten.emscripten_fetch_attr_t {}
		emscripten.emscripten_fetch_attr_init(&fetch_attr)
		fetch_attr.onsuccess = fetch_success
		fetch_attr.onerror = fetch_error
		fetch_attr.attributes = emscripten.EMSCRIPTEN_FETCH_LOAD_TO_MEMORY

		callback_info := new(RequestHandler)
		callback_info.user_handler = callback
		callback_info.user_data = user_data
		callback_info.ctx = context

		fetch_attr.userData = callback_info
		target_url := fmt.ctprintf("content/%s", url)
		emscripten.emscripten_fetch(&fetch_attr, target_url)
	} else {

		target_url := url
		when ODIN_PLATFORM_SUBTARGET == .Android {
			base := "."//SDL.GetBasePath()
			//target_url = fmt.ctprintf("%s/%s", base, url)
		} else {
			target_url = fmt.ctprintf("content/%s", url)
		}

		log.info("loading", target_url)

		io := SDL.IOFromFile(target_url, "r")

		file_size: uint = ---
		file_data :=  ([^]byte) (SDL.LoadFile_IO(io, &file_size, true))

		log.info("loaded", target_url, "with size", file_size)


		result := RequestResult {
			success = true,
			bytes = file_data[0:file_size],
			user_data = user_data,
		}

		callback(result)
	}
}


fetch_error :: proc "c" (fetch_result: ^emscripten.emscripten_fetch_t) {
	request_handler := (^RequestHandler)(fetch_result.userData)
	context = request_handler.ctx
	result := RequestResult {
		success = false,
		user_data = request_handler.user_data,
	}
    request_handler.user_handler(result)
	free(request_handler)
}


fetch_success :: proc "c" (fetch_result: ^emscripten.emscripten_fetch_t) {
	request_handler := (^RequestHandler)(fetch_result.userData)
	context = request_handler.ctx
	result := RequestResult {
		success = true,
		user_data = request_handler.user_data,
		bytes = (([^]byte)(fetch_result.data))[0:fetch_result.numBytes],
	}

    request_handler.user_handler(result)
	free(request_handler)
}
