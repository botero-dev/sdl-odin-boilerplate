
package main

import "core:fmt"
import "core:log"

import "engine:ui"
import ab "engine:."

main :: proc() {
	fmt.println("hello world")
	ab.app_init(nil, init, iterate)
}

init :: proc() {
	log.info("init")
	ui.create_window("Editor", {1280, 720})
}

iterate :: proc() {

	layout_panels()

	ab.render_layout(&ui.render_commands)
	ab.draw_present()
}

panel_fs_state: Panel_Filesystem_State

layout_panels :: proc() {
	
	ui.layout_begin()

	fill := ui.Sizing{type = .Weight, amount = 0.0}
	ui.layout_linear_child({fill, fill})
	ui.layout_container(ui.Layout_Linear_Horizontal {1}, "root_h")

		ui.layout_linear_child({fill, fill})

		ui.layout_container(ui.Layout_Linear_Vertical { 1 }, "root_v")

			{
				layout_tabgroup("scene")
				layout_scene()
			}

			{
				layout_tabgroup("filesystem")
				layout_filesystem(&panel_fs_state)
			}

		ui.layout_close()

		ui.layout_linear_child({fill, fill})

		ui.layout_container(ui.Layout_Linear_Horizontal { 1 }, "root_h2")

		{
			layout_tabgroup("hierarchy")
			layout_hierarchy()
		}

		{
			layout_tabgroup("inspector")
			layout_inspector()
		}
		ui.layout_close()

	ui.layout_close()


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

@(deferred_none=ui.layout_close)
layout_tabgroup :: proc(name: string) {
	fill := ui.Sizing{type = .Weight, amount = 0.0}
	ui.layout_linear_child({fill, fill})
	name_prefixed := fmt.tprintf("tabgroup_%", name)
	ui.layout_container(ui.Layout_Linear_Vertical{1}, name_prefixed)
	ui.layout_button(name)
}


layout_scene :: proc () {
	fill := ui.Sizing{type = .Weight, amount = 0.0}
	ui.layout_linear_child({fill, fill})
	ui.layout_container(ui.Layout_Linear_Vertical{1}, "scene")
	ui.layout_close()
}

layout_inspector :: proc () {
	fill := ui.Sizing{type = .Weight, amount = 0.0}
	ui.layout_linear_child({fill, fill})
	ui.layout_container(ui.Layout_Linear_Vertical{1}, "inspector")
	ui.layout_close()
}

layout_hierarchy :: proc () {
	fill := ui.Sizing{type = .Weight, amount = 0.0}
	ui.layout_linear_child({fill, fill})
	ui.layout_container(ui.Layout_Linear_Vertical{1}, "hierarchy")
	ui.layout_close()
}


layout_filesystem :: proc(panel_state: ^Panel_Filesystem_State) {

	fill := ui.Sizing{type = .Weight, amount = 0.0}
	ui.layout_linear_child({fill, fill})


	style_container := ui.get_current_style(&container_style_handle, ui.ContainerStyle)

	ui.layout_container(ui.Layout_Linear_Vertical{ style_container.separation }, "filesystem")

	layout_nav_bar()

	along := ui.Sizing{type = .Ratio, amount = 0.5}
	across := ui.Sizing{type = .Ratio, amount = 1.0}

	child_sizing: ui.LinearChildSizingFixed
	children_layout: ui.ChildrenLayout

	if panel_state.split_mode == .Horizontal { 
		children_layout = ui.Layout_Linear_Horizontal{style_container.separation}
		child_sizing = { width = along, height = across }
	} else if panel_state.split_mode == .Vertical { 
		children_layout = ui.Layout_Linear_Vertical{style_container.separation} 
		child_sizing = { width = across, height = along }
	}	

	ui.layout_linear_child({fill, fill})

	showing_content_panel := (panel_state.split_mode != .None)
	if showing_content_panel {
		ui.layout_container(children_layout, "children aa")
		ui.layout_linear_child(child_sizing)
	}

	layout_dir_panel(show_files = !showing_content_panel)

	if showing_content_panel {
		ui.layout_linear_child(child_sizing)
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
	ui.layout_container(ui.Layout_Linear_Horizontal{}, "nav bar")

	ui.layout_button("back")
	ui.layout_button("fwd")

	fill := ui.Sizing {.Weight, 0}
	ui.layout_linear_child({fill, fill})
	ui.layout_textbox("/path/to/asset")
	ui.layout_button("view", nil, proc (){
		panel_fs_state.split_mode = Panel_Filesystem_Split_Mode((i32(panel_fs_state.split_mode) + 1) % 3)
	})


	ui.layout_close()
}

layout_dir_panel :: proc(show_files: bool) {
	ui.layout_container(ui.Layout_Linear_Vertical{2}, "dir panel")

	for idx in 0..<5 {
		ui.layout_button("aaaaa")
		if show_files {
			ui.layout_button("  bbbbb")
		}
	}
	ui.layout_close()
}

layout_content_panel :: proc() {
	ui.layout_container(ui.Layout_Linear_Vertical{5}, "content panel")

	for idx in 0..<5 {
		ui.layout_button("bbbbb")
	}
	ui.layout_close()

}

Panel_Layout_State :: struct {

}




Panel_State_Inspector :: struct {

}

Panel_State_Scene :: struct {

}

