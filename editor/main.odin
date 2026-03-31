
package main

import "core:fmt"
import "core:log"

import "engine:ui"
import ab "engine:."

main :: proc() {
	fmt.println("hello world")
	ab.app_init(init, iterate)
}

init :: proc() {

}

iterate :: proc() {

	layout_panels()
}

panel_fs_state: Panel_Filesystem_State

layout_panels :: proc() {
	ui.layout_begin()

	layout_filesystem(&panel_fs_state)

	ui.layout_end()
}

Panel_Filesystem_Split_Mode :: enum {
	None,
	Horizontal,
	Vertical,
}

Panel_Filesystem_State :: struct {
	split_mode: Panel_Filesystem_Split_Mode,
}

container_style_handle := ui.style_class("Container")

layout_filesystem :: proc(panel_state: ^Panel_Filesystem_State) {


	style_container := ui.get_current_style(&container_style_handle, ui.ContainerStyle)

	ui.layout_container(ui.Layout_Linear_Vertical{ style_container.separation })
	layout_nav_bar()


	if panel_state.split_mode == .Horizontal { 
		ui.layout_container(ui.Layout_Linear_Horizontal{style_container.separation})
	}	else if panel_state.split_mode == .Vertical { 
		ui.layout_container(ui.Layout_Linear_Vertical{style_container.separation}) 
	}

	showing_content_panel := (panel_state.split_mode != .None)
	layout_dir_panel(show_files = !showing_content_panel)

	if showing_content_panel {
		layout_content_panel()
		ui.layout_close()
	}

	ui.layout_close()
}

IconRef :: struct {
	key: string,
	index: int,
}

icon_back := IconRef { key = "back" }

layout_nav_bar :: proc() {
	ui.layout_container(ui.Layout_Linear_Horizontal{})

	ui.layout_button("hellope")

	ui.layout_close()
}

layout_dir_panel :: proc(show_files: bool) {

}

layout_content_panel :: proc() {

}

Panel_Layout_State :: struct {

}




Panel_State_Inspector :: struct {

}

Panel_State_Scene :: struct {

}

