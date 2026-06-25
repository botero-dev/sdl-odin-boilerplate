package ui

import "core:log"

import clay "../clay-odin"

/*
    panel system lets you specify panel id+callback, and then
    you can have a data driven layout that you can save and modify
*/

PanelLayoutCallback :: #type proc()

PanelLayoutDefinition :: struct {
    callback: PanelLayoutCallback,
    name: string,
    grow: bool,
    show_tab: bool,
}

panel_layout_definitions: [dynamic]PanelLayoutDefinition
panel_layout_map: map[string]int


PanelLayoutRegisteredItem :: struct {
    definition: int
}

PanelLayoutGroup :: struct {
    direction: LayoutDirection,
    grow: bool,
    show_tabs: bool,
    can_relayout: bool,
    items: [dynamic]PanelLayoutItem,
}

PanelLayoutItem :: union {
    PanelLayoutGroup,
    PanelLayoutRegisteredItem,
}


PanelLayout :: struct {
    root: PanelLayoutItem,
}

panels_inited := false

panel_bgcolor := Color {0.2, 0.2, 0.2, 1}
window_bgcolor := Color {0.4, 0.4, 0.4, 1}
inactive_tab_bgcolor := Color {0.15, 0.15, 0.15, 1}
separator_bgcolor := Color {0.1, 0.1, 0.1, 1}

style_tab_button: StyleClass
style_tab_button_inactive: StyleClass
style_tab_bar: StyleClass
style_panel_bg: StyleClass

style_panel_container: StyleClass

init_styles :: proc() {
    tab_style := ButtonStyle {}

    tab_style.idle_box = BoxStyleColored {
        padding = {12, 12, 4, 4},
		//border_width = {0, 0, 0, 0},
        corner_radii = {4, 4, 0, 0},
        background = panel_bgcolor,
    }

    tab_style.hover_box = tab_style.idle_box
    tab_style.pressed_box = tab_style.idle_box

    style_tab_button = style_class("Button", "tab")
    push_style(&style_tab_button, tab_style)    

    tab_style_inactive := ButtonStyle {}
    tab_style_inactive.idle_box = BoxStyleColored {
        padding = {12, 12, 4, 4},
		//border_width = {0, 0, 0, 0},
        corner_radii = {4, 4, 0, 0},
        background = inactive_tab_bgcolor,
    }

    tab_style_inactive.hover_box = tab_style_inactive.idle_box
    tab_style_inactive.pressed_box = tab_style_inactive.idle_box
    
    style_tab_button_inactive = style_class("Button", "tab_inactive")
    push_style(&style_tab_button_inactive, tab_style_inactive)
    

    panel := BoxStyleColored {
        padding = {2,2,2,2},
        corner_radii = {0,0,0,0},
        background = panel_bgcolor
    }
    style_panel_bg = style_class("Box", "panel")
    push_style(&style_panel_bg, panel)

    tab_bar := BoxStyleColored {
        background = separator_bgcolor
    }

    style_tab_bar = style_class("Box", "tab_bar")
    push_style(&style_tab_bar, tab_bar)    

}



panels_register_definition :: proc (definition: PanelLayoutDefinition) -> int {
    if !panels_inited {
        panels_inited = true
        init_styles()
    }

    register_retval := append(&panel_layout_definitions, definition)

    panel_register_id := len(panel_layout_definitions)-1
    panel_layout_map[definition.name] = panel_register_id
    return panel_register_id
}

panels_present_layout :: proc (panel_layout: PanelLayout) {


    panels_present_item(panel_layout.root)


}

panels_present_item :: proc (item: PanelLayoutItem) {
    switch casted in item {
        case PanelLayoutGroup:
            panels_present_group(casted)
        case PanelLayoutRegisteredItem:
            panels_present_registered_item(casted)
    }
}

panels_present_group :: proc (group: PanelLayoutGroup) {
    current := layout_stack[len(layout_stack)-1]
    #partial switch layout_type in current {
        case Layout_Extend:
             layout_overlay_child({sizing_x = .Fill, sizing_y = .Fill})
        case Layout_Overlay_Float:
             layout_overlay_child({sizing_x = .Fill, sizing_y = .Fill})
        case Layout_Linear_Horizontal:
            layout_linear_child({
                width= group.grow ? {type = .Weight, amount = 1} : {type = .Fit},
                height= {type = .Weight},
            })
        
        case Layout_Linear_Vertical:
            layout_linear_child({
                width= {type = .Weight},
                height= group.grow ? {type = .Weight, amount = 1} : {type = .Fit},
            })
    }	

    if group.direction == .Horizontal {
        layout_container(Layout_Linear_Horizontal{separation = 4}) 
    }
    if group.direction == .Vertical {
        layout_container(Layout_Linear_Vertical{separation = 4})
    }

    for item in group.items {
        panels_present_item(item)
    }

    layout_close()
}

panels_present_registered_item :: proc (item: PanelLayoutRegisteredItem) {
    definition := panel_layout_definitions[item.definition]

    current := layout_stack[len(layout_stack)-1]
    #partial switch layout_type in current {
        case Layout_Extend:
             layout_overlay_child({sizing_x = .Fill, sizing_y = .Fill})
        case Layout_Overlay_Float:
             layout_overlay_child({sizing_x = .Fill, sizing_y = .Fill})
        case Layout_Linear_Horizontal:
            layout_linear_child({
                width= definition.grow ? {type = .Weight, amount=1} : {type=.Fit},
                height= {type = .Weight, amount = 1},
            })
        
        case Layout_Linear_Vertical:
            layout_linear_child({
                width= {type = .Weight, amount = 1},
                height= definition.grow ? {type = .Weight, amount = 1} : {type =.Fit},
            })
    }	
    

    if definition.show_tab {
        layout_container(Layout_Linear_Vertical {separation = 0})

            layout_linear_child({
                width= {type = .Weight},
                height= {type = .Fit},
            })
            layout_container(Layout_Linear_Horizontal {separation = 4}, &style_tab_bar)
                layout_button(definition.name, &style_tab_button)
                layout_button("other", &style_tab_button_inactive)
            layout_close()

        layout_linear_child({
            width= {type = .Weight},
            height= {type = .Weight},
        })
    }

    //layout_container(Layout_Overlay{}) // content container

    // opens actual content
    
    _layout_create(Layout_Extend{})
   	

    panel := BoxStyleColored {
        padding = {2,2,2,2},
        corner_radii = {0,0,0,0},
        background = panel_bgcolor
    }

    config_box_style(&clay_elem, panel)
	
    _layout_open(definition.name)

    definition.callback()

    layout_close() // content container


    if definition.show_tab {
        layout_close()
    }
}
