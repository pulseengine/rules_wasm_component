// Camera sensor component implementation
wit_bindgen::generate!({
    world: "camera-sensor",
    exports: {
        "sensor:interfaces/camera": Camera,
    },
});

use exports::sensor::interfaces::camera::{Frame, Guest};

struct Camera;

impl Guest for Camera {
    fn capture() -> Frame {
        Frame {
            width: 1920,
            height: 1080,
            data: vec![0; 1920 * 1080 * 3], // RGB data
            timestamp: 0,
        }
    }
    
    fn get_resolution() -> (u32, u32) {
        (1920, 1080)
    }
    
    fn set_resolution(width: u32, height: u32) {
        // In a real implementation, this would configure the camera
        println!("Setting resolution to {}x{}", width, height);
    }
}