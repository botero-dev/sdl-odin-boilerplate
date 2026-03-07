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
	callback: RequestCallback,
	user_data: rawptr,
}

RequestCallback :: #type proc(result: RequestResult)

// async on web, synchronous on desktop
request_data :: proc (url: cstring, user_data: rawptr, callback: RequestCallback) {

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


		io := SDL.AsyncIOFromFile(target_url, "r")

		file_size := u64(SDL.GetAsyncIOSize(io))

		data := make([]byte, file_size)

		handler := new(RequestHandler)
		handler.callback = callback
		handler.user_data = user_data


		success := SDL.ReadAsyncIO(io, &data[0], 0, file_size, load_queue, handler)
		append(&pending_tasks, io)
	}
}

pending_tasks: [dynamic]^SDL.AsyncIO

idle_process_async :: proc() {
	outcome: SDL.AsyncIOOutcome
	completed := SDL.GetAsyncIOResult(load_queue, &outcome)
	if completed {
		log.info("outcome:", outcome)
		if outcome.type == .READ {
			handler := (^RequestHandler)(outcome.userdata)
			buf := ([^]u8) (outcome.buffer)
			handler.callback({
				true,
				buf[:outcome.bytes_transferred],
				handler.user_data,
			})
			r := SDL.CloseAsyncIO(outcome.asyncio, true, load_queue, nil)
		}
	}
}


fetch_error :: proc "c" (fetch_result: ^emscripten.emscripten_fetch_t) {
	request_handler := (^RequestHandler)(fetch_result.userData)
	context = ctx
	result := RequestResult {
		success = false,
		user_data = request_handler.user_data,
	}
    request_handler.callback(result)
	free(request_handler)
}


fetch_success :: proc "c" (fetch_result: ^emscripten.emscripten_fetch_t) {
	request_handler := (^RequestHandler)(fetch_result.userData)
	context = ctx
	result := RequestResult {
		success = true,
		user_data = request_handler.user_data,
		bytes = (([^]byte)(fetch_result.data))[0:fetch_result.numBytes],
	}

    request_handler.callback(result)
	free(request_handler)
}
