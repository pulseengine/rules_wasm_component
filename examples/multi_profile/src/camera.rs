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
    fn capture_frame() -> Result<Frame, String> {
        Ok(Frame {
            width: 1920,
            height: 1080,
            data: vec![0; 1920 * 1080 * 3], // RGB data
            timestamp: 0,
        })
    }
    
    fn configure(frame_rate: u32, resolution: String) -> Result<(), String> {
        println!("Configuring camera: {}fps, {}", frame_rate, resolution);
        Ok(())
    }
    
    fn get_status() -> String {
        "Camera ready".to_string()
    }
}