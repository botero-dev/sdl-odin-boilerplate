#+build linux, darwin, windows
package engine

import "core:runtime"

import "../vendor/back"

back_register_segfault_handler :: proc() {
    back.register_segfault_handler()
}

back_get_assertion_failure_proc :: proc() -> runtime.Assertion_Failure_Proc {
    return back.assertion_failure_proc
}
