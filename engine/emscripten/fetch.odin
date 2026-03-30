/*
* Copyright 2016 The Emscripten Authors.  All rights reserved.
* Emscripten is available under two separate licenses, the MIT license and the
* University of Illinois/NCSA Open Source License.  Both these licenses can be
* found in the LICENSE file.
*/
package emscripten

import "core:c"

_ :: c



// Emscripten fetch attributes:
// If passed, the body of the request will be present in full in the onsuccess()
// handler.
EMSCRIPTEN_FETCH_LOAD_TO_MEMORY  :: 1

// If passed, the intermediate streamed bytes will be passed in to the
// onprogress() handler. If not specified, the onprogress() handler will still
// be called, but without data bytes.  Note: Firefox only as it depends on
// 'moz-chunked-arraybuffer'.
EMSCRIPTEN_FETCH_STREAM_DATA :: 2

// If passed, the final download will be stored in IndexedDB. If not specified,
// the file will only reside in browser memory.
EMSCRIPTEN_FETCH_PERSIST_FILE :: 4

// Looks up if the file already exists in IndexedDB, and if so, it is returned
// without redownload. If a partial transfer exists in IndexedDB, the download
// will resume from where it left off and run to completion.
// EMSCRIPTEN_FETCH_APPEND, EMSCRIPTEN_FETCH_REPLACE and
// EMSCRIPTEN_FETCH_NO_DOWNLOAD are mutually exclusive.  If none of these three
// flags is specified, the fetch operation is implicitly treated as if
// EMSCRIPTEN_FETCH_APPEND had been passed.
EMSCRIPTEN_FETCH_APPEND :: 8

// If the file already exists in IndexedDB, the old file will be deleted and a
// new download is started.
// EMSCRIPTEN_FETCH_APPEND, EMSCRIPTEN_FETCH_REPLACE and
// EMSCRIPTEN_FETCH_NO_DOWNLOAD are mutually exclusive.  If you would like to
// perform an XHR that neither reads or writes to IndexedDB, pass this flag
// EMSCRIPTEN_FETCH_REPLACE, and do not pass the flag
// EMSCRIPTEN_FETCH_PERSIST_FILE.
EMSCRIPTEN_FETCH_REPLACE :: 16

// If specified, the file will only be looked up in IndexedDB, but if it does
// not exist, it is not attempted to be downloaded over the network but an error
// is raised.
// EMSCRIPTEN_FETCH_APPEND, EMSCRIPTEN_FETCH_REPLACE and
// EMSCRIPTEN_FETCH_NO_DOWNLOAD are mutually exclusive.
EMSCRIPTEN_FETCH_NO_DOWNLOAD :: 32

// If specified, emscripten_fetch() will synchronously run to completion before
// returning.  The callback handlers will be called from within
// emscripten_fetch() while the operation is in progress.
EMSCRIPTEN_FETCH_SYNCHRONOUS :: 64

EMSCRIPTEN_FETCH_WAITABLE :: 128

// Specifies the parameters for a newly initiated fetch operation.
emscripten_fetch_attr_t :: struct {
	// 'POST', 'GET', etc.
	requestMethod: [32]i8,

	// Custom data that can be tagged along the process.
	userData: rawptr,
	onsuccess:          proc "c" (^emscripten_fetch_t),
	onerror:            proc "c" (^emscripten_fetch_t),
	onprogress:         proc "c" (^emscripten_fetch_t),
	onreadystatechange: proc "c" (^emscripten_fetch_t),

	// EMSCRIPTEN_FETCH_* attributes
	attributes: u32,

	// Specifies the amount of time the request can take before failing due to a
	// timeout.
	timeoutMSecs: u32,

	// Indicates whether cross-site access control requests should be made using
	// credentials.
	withCredentials: bool,

	// Specifies the destination path in IndexedDB where to store the downloaded
	// content body. If this is empty, the transfer is not stored to IndexedDB at
	// all.  Note that this struct does not contain space to hold this string, it
	// only carries a pointer.
	// Calling emscripten_fetch() will make an internal copy of this string.
	destinationPath: cstring,

	// Specifies the authentication username to use for the request, if necessary.
	// Note that this struct does not contain space to hold this string, it only
	// carries a pointer.
	// Calling emscripten_fetch() will make an internal copy of this string.
	userName: cstring,

	// Specifies the authentication username to use for the request, if necessary.
	// Note that this struct does not contain space to hold this string, it only
	// carries a pointer.
	// Calling emscripten_fetch() will make an internal copy of this string.
	password: cstring,

	// Points to an array of strings to pass custom headers to the request. This
	// array takes the form
	// {"key1", "value1", "key2", "value2", "key3", "value3", ..., 0 }; Note
	// especially that the array needs to be terminated with a null pointer.
	requestHeaders: [^]cstring,

	// Pass a custom MIME type here to force the browser to treat the received
	// data with the given type.
	overriddenMimeType: cstring,

	// If non-zero, specifies a pointer to the data that is to be passed as the
	// body (payload) of the request that is being performed. Leave as zero if no
	// request body needs to be sent.  The memory pointed to by this field is
	// provided by the user, and needs to be valid throughout the duration of the
	// fetch operation. If passing a non-zero pointer into this field, make sure
	// to implement *both* the onsuccess and onerror handlers to be notified when
	// the fetch finishes to know when this memory block can be freed. Do not pass
	// a pointer to memory on the stack or other temporary area here.
	requestData: cstring,

	// Specifies the length of the buffer pointed by 'requestData'. Leave as 0 if
	// no request body needs to be sent.
	requestDataSize: c.size_t,
}

emscripten_fetch_t :: struct {
	// Unique identifier for this fetch in progress.
	id: u32,

	// Custom data that can be tagged along the process.
	userData: rawptr,

	// The remote URL set in the original request.
	url: cstring,

	// In onsuccess() handler:
	//   - If the EMSCRIPTEN_FETCH_LOAD_TO_MEMORY attribute was specified for the
	//     transfer, this points to the body of the downloaded data. Otherwise
	//     this will be null.
	// In onprogress() handler:
	//   - If the EMSCRIPTEN_FETCH_STREAM_DATA attribute was specified for the
	//     transfer, this points to a partial chunk of bytes related to the
	//     transfer. Otherwise this will be null.
	// The data buffer provided here has identical lifetime with the
	// emscripten_fetch_t object itself, and is freed by calling
	// emscripten_fetch_close() on the emscripten_fetch_t pointer.
	data: cstring,

	// Specifies the length of the above data block in bytes. When the download
	// finishes, this field will be valid even if EMSCRIPTEN_FETCH_LOAD_TO_MEMORY
	// was not specified.
	numBytes: u64,

	// If EMSCRIPTEN_FETCH_STREAM_DATA is being performed, this indicates the byte
	// offset from the start of the stream that the data block specifies. (for
	// onprogress() streaming XHR transfer, the number of bytes downloaded so far
	// before this chunk)
	dataOffset: u64,

	// Specifies the total number of bytes that the response body will be.
	// Note: This field may be zero, if the server does not report the
	// Content-Length field.
	totalBytes: u64,

	// Specifies the readyState of the XHR request:
	// 0: UNSENT: request not sent yet
	// 1: OPENED: emscripten_fetch has been called.
	// 2: HEADERS_RECEIVED: emscripten_fetch has been called, and headers and
	//    status are available.
	// 3: LOADING: download in progress.
	// 4: DONE: download finished.
	// See https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/readyState
	readyState: u16,

	// Specifies the status code of the response.
	status: u16,

	// Specifies a human-readable form of the status code.
	statusText: [64]i8,

	// For internal use only.
	__attributes: emscripten_fetch_attr_t,

	// The response URL set by the fetch. It will be null until HEADERS_RECEIVED
	// readyState in async, or until completion in sync.
	responseUrl: cstring,
}

@(default_calling_convention="c", link_prefix="")
foreign {
	// Clears the fields of an emscripten_fetch_attr_t structure to their default
	// values in a future-compatible manner.
	emscripten_fetch_attr_init :: proc(fetch_attr: ^emscripten_fetch_attr_t) ---

	// Initiates a new Emscripten fetch operation, which downloads data from the
	// given URL or from IndexedDB database.
	emscripten_fetch      :: proc(fetch_attr: ^emscripten_fetch_attr_t, url: cstring) -> ^emscripten_fetch_t ---
	emscripten_fetch_wait :: proc(fetch: ^emscripten_fetch_t, timeoutMSecs: f64) -> i32 ---

	// Closes a finished or an executing fetch operation and frees up all memory. If
	// the fetch operation was still executing, the onerror() handler will be called
	// in the calling thread before this function returns.
	emscripten_fetch_close :: proc(fetch: ^emscripten_fetch_t) -> i32 ---

	// Gets the size (in bytes) of the response headers as plain text.
	// This must be called on the same thread as the fetch originated on.
	// Note that this will return 0 if readyState < HEADERS_RECEIVED.
	emscripten_fetch_get_response_headers_length :: proc(fetch: ^emscripten_fetch_t) -> c.size_t ---

	// Gets the response headers as plain text. dstSizeBytes should be
	// headers_length + 1 (for the null terminator).
	// This must be called on the same thread as the fetch originated on.
	emscripten_fetch_get_response_headers :: proc(fetch: ^emscripten_fetch_t, dst: cstring, dstSizeBytes: c.size_t) -> c.size_t ---

	// Converts the plain text headers into an array of strings. This array takes
	// the form {"key1", "value1", "key2", "value2", "key3", "value3", ..., 0 };
	// Note especially that the array is terminated with a null pointer.
	emscripten_fetch_unpack_response_headers :: proc(headersString: cstring) -> [^]cstring ---

	// This frees the memory used by the array of headers. Call this when finished
	// with the data returned by emscripten_fetch_unpack_response_headers.
	emscripten_fetch_free_unpacked_response_headers :: proc(unpackedHeaders: [^]cstring) ---
}
