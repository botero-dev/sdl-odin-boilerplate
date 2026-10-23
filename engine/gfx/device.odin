package gfx

import SDL "vendor:sdl3"

device: ^SDL.GPUDevice

device_get :: proc() -> ^SDL.GPUDevice {
    if device == nil {
        device = SDL.CreateGPUDevice({.SPIRV}, false, nil)
    }

    return device
}