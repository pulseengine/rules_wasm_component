// Simplified API Gateway implementation for microservices architecture

// Import the generated WIT bindings
use api_gateway_bindings::exports::gateway::microservices::routing::{
    Guest, RouteRequest, RouteResponse, RouteRule, ServiceEndpoint,
};

// Component implementation
struct ApiGateway;

impl Guest for ApiGateway {
    fn discover_services() -> Vec<ServiceEndpoint> {
        vec![
            ServiceEndpoint {
                name: "user-service".to_string(),
                version: "v1.0.0".to_string(),
                health_status: "healthy".to_string(),
                load: 0.5,
                endpoints: vec!["http://user-service:8080".to_string()],
            },
            ServiceEndpoint {
                name: "product-service".to_string(),
                version: "v1.2.0".to_string(),
                health_status: "healthy".to_string(),
                load: 0.3,
                endpoints: vec!["http://product-service:8080".to_string()],
            },
        ]
    }

    fn register_service(endpoint: ServiceEndpoint) {
        println!("Registering service: {}", endpoint.name);
    }

    fn route(request: RouteRequest, _rules: Vec<RouteRule>) -> RouteResponse {
        println!("Routing request: {} {}", request.method, request.path);
        RouteResponse {
            status: 200,
            headers: vec![("content-type".to_string(), "application/json".to_string())],
            body: Some(b"Hello from API Gateway".to_vec()),
            service: "api-gateway".to_string(),
            duration_ms: 10,
        }
    }
}

// Export the component implementation
api_gateway_bindings::export!(ApiGateway with_types_in api_gateway_bindings);
