// Object detection AI component implementation
wit_bindgen::generate!({
    world: "object-detector",
    imports: {
        "sensor:interfaces/camera": sensor::interfaces::camera,
    },
    exports: {
        "ai:interfaces/detector": Detector,
    },
});

use sensor::interfaces::camera::{Frame};
use exports::ai::interfaces::detector::{Detection, Guest};

struct Detector;

impl Guest for Detector {
    fn detect(frame: Frame) -> Vec<Detection> {
        // Simulate object detection
        vec![
            Detection {
                class: "person".to_string(),
                confidence: 0.95,
                x: 100,
                y: 200,
                width: 150,
                height: 300,
            },
            Detection {
                class: "car".to_string(),
                confidence: 0.87,
                x: 500,
                y: 300,
                width: 200,
                height: 150,
            },
        ]
    }
    
    fn set_threshold(threshold: f32) {
        println!("Setting confidence threshold to {}", threshold);
    }
    
    fn get_model_info() -> String {
        "YOLOv5 Object Detection Model v1.0".to_string()
    }
}