use gateway::api::exports::wasi::http::incoming_handler::{Guest, IncomingRequest, ResponseOutparam};
use gateway::api::exports::routing::{RouteRequest, RouteResponse, RouteConfig};
use gateway::api::user_api::{UserRequest, UserResponse};
use gateway::api::analytics_api::AnalyticsEvent;
use gateway::api::metrics::{MetricRequest, MetricResponse};
use gateway::api::device_management::{DeviceData, DeviceStatus};

// Re-export the generated world
use gateway::api::Gateway;

struct GatewayComponent;

impl Guest for GatewayComponent {
    fn handle(request: IncomingRequest, response_out: ResponseOutparam) {
        // Gateway acts as a reverse proxy/router
        let path = get_request_path(&request);
        let method = get_request_method(&request);
        
        // Create route request
        let route_req = RouteRequest {
            path: path.clone(),
            method: method.clone(),
            headers: vec![],
            body: None,
        };
        
        // Route to appropriate service based on path
        let response = match path.as_str() {
            path if path.starts_with("/users") => route_to_user_service(route_req),
            path if path.starts_with("/analytics") => route_to_analytics_service(route_req),
            path if path.starts_with("/metrics") => route_to_metrics_service(route_req),
            path if path.starts_with("/devices") => route_to_device_service(route_req),
            _ => RouteResponse {
                status: 404,
                headers: vec![],
                body: Some(r#"{"error": "Service not found"}"#.to_string()),
            },
        };
        
        send_response(response_out, response);
    }
}

impl gateway::api::exports::routing::Guest for GatewayComponent {
    fn route_request(request: RouteRequest) -> RouteResponse {
        // Main routing logic implementation
        match request.path.as_str() {
            path if path.starts_with("/users") => route_to_user_service(request),
            path if path.starts_with("/analytics") => route_to_analytics_service(request),
            path if path.starts_with("/metrics") => route_to_metrics_service(request),
            path if path.starts_with("/devices") => route_to_device_service(request),
            _ => RouteResponse {
                status: 404,
                headers: vec![("content-type".to_string(), "application/json".to_string())],
                body: Some(r#"{"error": "Route not found"}"#.to_string()),
            },
        }
    }
}

fn route_to_user_service(request: RouteRequest) -> RouteResponse {
    // Extract user operation from path and method
    let user_req = UserRequest {
        action: match request.method.as_str() {
            "GET" => "get".to_string(),
            "POST" => "create".to_string(),
            "PUT" => "update".to_string(),
            "DELETE" => "delete".to_string(),
            _ => "get".to_string(),
        },
        user_id: extract_user_id_from_path(&request.path),
        data: request.body,
    };
    
    // Call user service through imported interface
    let user_response = gateway::api::user_api::handle_user(user_req);
    
    let status = if user_response.success { 200 } else { 400 };
    let body = if user_response.success {
        user_response.data
    } else {
        Some(format!(r#"{{"error": "{}"}}"#, user_response.error.unwrap_or_default()))
    };
    
    RouteResponse {
        status,
        headers: vec![("content-type".to_string(), "application/json".to_string())],
        body,
    }
}

fn route_to_analytics_service(request: RouteRequest) -> RouteResponse {
    // Parse analytics event from request body
    let event = AnalyticsEvent {
        event_type: "api_request".to_string(),
        user_id: extract_user_id_from_headers(&request.headers),
        properties: vec![
            ("path".to_string(), request.path.clone()),
            ("method".to_string(), request.method.clone()),
        ],
        timestamp: current_timestamp(),
    };
    
    // Send event to analytics service
    gateway::api::analytics_api::collect_event(event);
    
    RouteResponse {
        status: 202,
        headers: vec![("content-type".to_string(), "application/json".to_string())],
        body: Some(r#"{"status": "event_recorded"}"#.to_string()),
    }
}

fn route_to_metrics_service(request: RouteRequest) -> RouteResponse {
    // Parse metrics query from request
    let metric_req = MetricRequest {
        metric_name: extract_metric_name_from_path(&request.path),
        time_range: (current_timestamp() - 3600, current_timestamp()), // Last hour
        filters: vec![],
    };
    
    // Query metrics service
    let metric_response = gateway::api::metrics::query_metrics(metric_req);
    
    let status = if metric_response.success { 200 } else { 400 };
    let body = metric_response.data.or_else(|| {
        metric_response.error.map(|e| format!(r#"{{"error": "{}"}}"#, e))
    });
    
    RouteResponse {
        status,
        headers: vec![("content-type".to_string(), "application/json".to_string())],
        body,
    }
}

fn route_to_device_service(request: RouteRequest) -> RouteResponse {
    match request.method.as_str() {
        "POST" => {
            // Handle device data submission
            let device_data = DeviceData {
                device_id: "sensor-001".to_string(),
                sensor_type: "temperature".to_string(),
                value: "23.5".to_string(),
                timestamp: current_timestamp(),
            };
            
            gateway::api::device_management::collect_data(device_data);
            
            RouteResponse {
                status: 201,
                headers: vec![("content-type".to_string(), "application/json".to_string())],
                body: Some(r#"{"status": "data_received"}"#.to_string()),
            }
        }
        "GET" => {
            // Handle device status query
            let device_id = extract_device_id_from_path(&request.path);
            let status = gateway::api::device_management::get_status(device_id);
            
            let response_body = format!(
                r#"{{"device_id": "{}", "online": {}, "last_seen": {}}}"#,
                status.device_id, status.online, status.last_seen
            );
            
            RouteResponse {
                status: 200,
                headers: vec![("content-type".to_string(), "application/json".to_string())],
                body: Some(response_body),
            }
        }
        _ => RouteResponse {
            status: 405,
            headers: vec![("content-type".to_string(), "application/json".to_string())],
            body: Some(r#"{"error": "Method not allowed"}"#.to_string()),
        },
    }
}

// Helper functions for path/header parsing
fn get_request_path(request: &IncomingRequest) -> String {
    "/users".to_string()  // Placeholder implementation
}

fn get_request_method(request: &IncomingRequest) -> String {
    "GET".to_string()  // Placeholder implementation
}

fn extract_user_id_from_path(path: &str) -> Option<String> {
    // Extract user ID from path like "/users/123"
    path.split('/').nth(2).map(|s| s.to_string())
}

fn extract_user_id_from_headers(headers: &[(String, String)]) -> Option<String> {
    headers.iter()
        .find(|(key, _)| key.to_lowercase() == "x-user-id")
        .map(|(_, value)| value.clone())
}

fn extract_metric_name_from_path(path: &str) -> String {
    // Extract metric name from path like "/metrics/cpu_usage"
    path.split('/').nth(2).unwrap_or("default").to_string()
}

fn extract_device_id_from_path(path: &str) -> String {
    // Extract device ID from path like "/devices/sensor-001"
    path.split('/').nth(2).unwrap_or("unknown").to_string()
}

fn current_timestamp() -> u64 {
    1234567890  // Placeholder implementation
}

fn send_response(response_out: ResponseOutparam, response: RouteResponse) {
    // Simplified response sending
    println!("Gateway response: {} - {:?}", response.status, response.body);
}

// Export the component
gateway::api::export!(GatewayComponent with_types_in gateway::api);