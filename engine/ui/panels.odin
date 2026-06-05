package ui

import "core:log"


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


panels_register_definition :: proc (definition: PanelLayoutDefinition) -> int {
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
    if group.grow {
        layout_linear_child({
            width= {type = .Weight},
            height= {type = .Weight},
        })

    }
    if group.direction == .Horizontal {
        layout_container(Layout_Linear_Horizontal{})
    }
    if group.direction == .Vertical {
        layout_container(Layout_Linear_Vertical{})
    }

    for item in group.items {
        panels_present_item(item)
    }

    layout_close()
}

panels_present_registered_item :: proc (item: PanelLayoutRegisteredItem) {
    definition := panel_layout_definitions[item.definition]

    if definition.grow {
        layout_linear_child({
            width= {type = .Weight},
            height= {type = .Weight},
        })
    }

    if definition.show_tab {
        layout_container(Layout_Linear_Vertical {})

        layout_button(definition.name)
    }


    definition.callback()

    if definition.show_tab {
        layout_close()
    }
}
