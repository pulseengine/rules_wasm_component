# Microservices Architecture with WAC + OCI

This example demonstrates a complete, production-ready microservices architecture using WebAssembly components composed with WAC (WebAssembly Composition) and distributed via OCI (Open Container Initiative) registries.

## Architecture Overview

The example showcases three major architectural patterns:

### 🛒 E-commerce Platform

- **Frontend**: Web application with React-like functionality
- **Services**: User management, product catalog, inventory, orders, shopping cart
- **External**: Payment processing, fraud detection, notifications
- **Infrastructure**: Search, analytics, recommendations

### 🏦 Financial Services Platform

- **Clients**: API gateway, mobile banking app
- **Core Services**: Accounts, transactions, balances, loans
- **Security**: Authentication, KYC, fraud monitoring, audit logging
- **External**: Credit bureau, payment rails
- **Analytics**: Risk assessment, regulatory reporting

### 🌐 IoT Edge Platform

- **Edge**: Local gateway with real-time processing
- **Device Management**: Registry, configuration, OTA updates
- **Data Pipeline**: Ingestion, stream processing, batch analytics
- **Storage**: Time-series database, data warehouse
- **AI/ML**: Inference engine, anomaly detection

## Key Features Demonstrated

### 🔀 Multi-Registry Architecture

```bazel
registries = [
    "local|localhost:5000|oci",                                    # Development
    "github|ghcr.io|oci|env|GITHUB_TOKEN",                        # Open source
    "docker|docker.io|oci|env|DOCKER_TOKEN",                      # Third-party
    "aws|*.dkr.ecr.us-west-2.amazonaws.com|oci|oauth|...",        # Production
    "azure|*.azurecr.io|oci|basic|...",                           # Backup
    "google|us-central1-docker.pkg.dev|oci|oauth|...",            # ML services
]
```

### 🔐 Enterprise Security

- **Component Signing**: All production components digitally signed
- **Registry Authentication**: Multiple auth methods (OAuth, tokens, basic)
- **Security Policies**: Enforce signing requirements per environment
- **Compliance**: SOC2, PCI-DSS, regulatory audit trails

### 🚀 Deployment Patterns

- **Development**: Local mocks + minimal containerized services
- **Staging**: Production-like with test data and staging registries
- **Production**: Full service mesh with enterprise security
- **Canary**: Traffic splitting between stable and canary versions

### 📊 Observability

- **Distributed Tracing**: Request flow across all services
- **Metrics Collection**: Performance, business, and system metrics
- **Centralized Logging**: Structured logs with correlation IDs
- **Health Monitoring**: Service health checks and circuit breakers

## Examples Breakdown

### 1. E-commerce Platform

```bazel
wac_microservices_app(
    name = "ecommerce_platform",
    frontend_component = ":web_frontend",
    services = {
        # Core business logic
        "user_service": "ghcr.io/company/ecommerce/user-service:v2.1.0",
        "product_catalog": "ghcr.io/company/ecommerce/product-catalog:v1.8.0",
        "inventory_service": "ghcr.io/company/ecommerce/inventory:v1.5.0",
        "order_service": "ghcr.io/company/ecommerce/orders:v2.0.0",

        # External services
        "payment_processor": "docker.io/stripe/payment-processor:v3.2.0",
        "fraud_detection": "docker.io/sift/fraud-detection:v2.0.0",

        # Infrastructure
        "search_service": "123456789.dkr.ecr.us-west-2.amazonaws.com/search:v2.5.0",
        "recommendation_engine": "us-central1-docker.pkg.dev/company/ml/recommendations:v1.8.0",
    },
)
```

**Architecture Benefits:**

- **Scalability**: Independent scaling of each service
- **Reliability**: Service isolation and circuit breakers
- **Development Velocity**: Teams can deploy independently
- **Technology Diversity**: Best tool for each service

### 2. Financial Services Platform

```bazel
wac_distributed_system(
    name = "fintech_platform",
    components = {
        "local": {
            "api_gateway": ":api_gateway",
            "mobile_app": ":mobile_app",
        },
        "oci": {
            # Highly regulated core services
            "account_service": "ghcr.io/bank/core/accounts:v3.0.0",
            "transaction_service": "ghcr.io/bank/core/transactions:v2.8.0",

            # Security and compliance
            "auth_service": "ghcr.io/bank/security/auth:v4.0.0",
            "fraud_monitor": "ghcr.io/bank/security/fraud:v3.1.0",
            "audit_service": "ghcr.io/bank/compliance/audit:v1.0.0",

            # External integrations
            "credit_bureau": "docker.io/experian/credit-check:v2.0.0",
            "payment_rails": "docker.io/fed/ach-processor:v1.8.0",
        },
    },
)
```

**Financial Services Requirements:**

- **Regulatory Compliance**: Audit trails, data residency, encryption
- **Security**: Multi-factor authentication, fraud detection, risk management
- **Availability**: 99.99% uptime, disaster recovery, failover
- **Performance**: Low latency for real-time transactions

### 3. IoT Edge Platform

```bazel
wac_distributed_system(
    name = "iot_edge_platform",
    components = {
        "local": {
            "edge_gateway": ":api_gateway",  # Edge processing
        },
        "oci": {
            # Device management
            "device_registry": "ghcr.io/iot/devices/registry:v2.0.0",
            "ota_updates": "ghcr.io/iot/devices/ota:v1.0.0",

            # Data processing
            "stream_processor": "ghcr.io/iot/data/stream:v2.8.0",
            "ml_inference": "us-central1-docker.pkg.dev/iot/ml/inference:v2.1.0",

            # Storage and analytics
            "time_series_db": "docker.io/influxdata/influxdb-wasm:v2.0.0",
            "data_warehouse": "us-central1-docker.pkg.dev/iot/analytics/warehouse:v1.0.0",
        },
    },
)
```

**IoT Platform Features:**

- **Edge Processing**: Local data processing to reduce latency
- **Device Management**: OTA updates, configuration, monitoring
- **Data Pipeline**: Real-time stream processing and batch analytics
- **ML Integration**: Edge inference and cloud model updates

## Component Interfaces

### API Gateway (wit/api_gateway.wit)

- **Authentication**: Multi-protocol auth (OAuth, API keys, JWT)
- **Routing**: Service discovery, load balancing, circuit breakers
- **Rate Limiting**: Per-user, per-service, and global limits
- **Monitoring**: Distributed tracing, metrics, logging

### Web Frontend (wit/web_frontend.wit)

- **UI Framework**: Component-based reactive UI
- **State Management**: Client-side state and caching
- **API Client**: Backend service communication
- **PWA Features**: Offline support, push notifications

### Mobile App (wit/mobile_app.wit)

- **Native Integration**: Touch events, sensors, camera
- **Device Features**: Location, battery, notifications
- **Offline Sync**: Background tasks, data synchronization
- **Platform APIs**: iOS/Android specific capabilities

## Environment Configuration

### Development Environment

```bash
# Local development with minimal services
bazel build //examples/microservices_architecture:ecommerce_development

# Uses local mocks + localhost registry
# Fast iteration, no external dependencies
```

### Staging Environment

```bash
# Production-like with test data
bazel build //examples/microservices_architecture:ecommerce_staging

# All production services with staging tags
# End-to-end integration testing
```

### Production Environment

```bash
# Full production deployment
bazel build //examples/microservices_architecture:ecommerce_platform

# Enterprise security, monitoring, compliance
# Multi-registry distribution
```

## Deployment Strategies

### Canary Deployment

```bazel
wac_compose_with_oci(
    name = "ecommerce_canary",
    oci_components = {
        # Stable production services (90% traffic)
        "user_service_stable": "ghcr.io/company/ecommerce/user-service:v2.0.0",

        # Canary versions (10% traffic)
        "user_service_canary": "ghcr.io/company/ecommerce/user-service:v2.1.0-canary",

        # Traffic management
        "traffic_splitter": "ghcr.io/company/infrastructure/traffic-splitter:v1.0.0",
    },
)
```

### Blue-Green Deployment

```bash
# Deploy to green environment
bazel build //examples/microservices_architecture:ecommerce_platform_green

# Run smoke tests
bazel test //examples/microservices_architecture:integration_tests

# Switch traffic from blue to green
kubectl apply -f k8s/traffic-switch-green.yaml
```

## Security Implementation

### Component Signing

```bazel
wasm_component_secure_publish(
    name = "publish_ecommerce_production",
    component = ":ecommerce_platform",
    security_policy = ":microservices_security_policy",
    signing_keys = ":production_signing_keys",
    target_registries = ["github", "aws"],
)
```

### Security Policies

```bazel
wasm_security_policy(
    name = "microservices_security_policy",
    default_signing_required = True,
    registry_policies = [
        "ghcr.io|required|production_signing_keys",
        "docker.io|required|production_signing_keys",
        "local|optional",
    ],
    component_policies = [
        "production-*|required|production_signing_keys",
        "staging-*|required|production_signing_keys",
        "dev-*|optional",
    ],
)
```

## Monitoring and Observability

### Metrics Collection

- **Business Metrics**: Orders/minute, revenue, conversion rates
- **System Metrics**: CPU, memory, network, storage
- **Application Metrics**: Response times, error rates, throughput
- **Security Metrics**: Authentication failures, rate limit hits

### Distributed Tracing

- **Request Correlation**: Trace requests across all services
- **Performance Analysis**: Identify bottlenecks and optimization opportunities
- **Error Tracking**: Root cause analysis for failures
- **Dependency Mapping**: Visualize service interactions

### Alerting

- **SLA Monitoring**: Service level objective violations
- **Error Rate Alerts**: Anomaly detection and thresholds
- **Resource Alerts**: CPU, memory, disk usage warnings
- **Business Alerts**: Revenue drops, conversion rate changes

## Performance Optimization

### Service-Level Optimizations

- **Caching**: Multi-level caching (CDN, application, database)
- **Database**: Read replicas, connection pooling, query optimization
- **Message Queues**: Asynchronous processing, load leveling
- **CDN**: Static asset delivery, geographic distribution

### Component-Level Optimizations

- **WASM Size**: Tree shaking, compression, code splitting
- **Memory Usage**: Efficient data structures, memory pools
- **CPU Usage**: Algorithm optimization, parallel processing
- **Network**: Request batching, compression, persistent connections

## Testing Strategy

### Unit Testing

```bash
# Test individual components
bazel test //examples/microservices_architecture:api_gateway_test
bazel test //examples/microservices_architecture:web_frontend_test
```

### Integration Testing

```bash
# Test service interactions
bazel test //examples/microservices_architecture:integration_tests
```

### Load Testing

```bash
# Performance and scalability testing
bazel test //examples/microservices_architecture:load_tests
```

### End-to-End Testing

```bash
# Full user journey testing
bazel test //examples/microservices_architecture:e2e_tests
```

## Operational Procedures

### Incident Response

1. **Detection**: Monitoring alerts trigger incident
2. **Triage**: Determine severity and impact
3. **Isolation**: Circuit breakers isolate failing services
4. **Rollback**: Quick rollback to last known good version
5. **Recovery**: Gradual traffic restoration after fix

### Capacity Planning

- **Traffic Forecasting**: Predict load based on business metrics
- **Resource Scaling**: Auto-scaling based on utilization
- **Cost Optimization**: Right-sizing instances and services
- **Performance Testing**: Regular load testing and benchmarking

### Disaster Recovery

- **Backup Strategy**: Regular backups of critical data
- **Multi-Region**: Deploy across multiple availability zones
- **Failover**: Automated failover to backup systems
- **Recovery Testing**: Regular DR drills and validation

## Best Practices

### Architecture Principles

- **Single Responsibility**: Each service has one clear purpose
- **Loose Coupling**: Services communicate via well-defined APIs
- **High Cohesion**: Related functionality grouped together
- **Stateless Design**: Services don't maintain client state

### Development Guidelines

- **API First**: Design APIs before implementation
- **Versioning**: Semantic versioning for backward compatibility
- **Documentation**: Comprehensive API and deployment docs
- **Testing**: Automated testing at all levels

### Operational Excellence

- **Infrastructure as Code**: All infrastructure defined in code
- **Continuous Deployment**: Automated deployment pipelines
- **Monitoring**: Comprehensive observability across all layers
- **Security**: Defense in depth, principle of least privilege

## Troubleshooting Guide

### Common Issues

#### Service Discovery Failures

```bash
# Check service registration
kubectl get services -n microservices

# Verify DNS resolution
nslookup user-service.microservices.svc.cluster.local
```

#### Authentication Problems

```bash
# Verify JWT tokens
echo $JWT_TOKEN | base64 -d | jq .

# Check certificate validity
openssl x509 -in cert.pem -text -noout
```

#### Performance Issues

```bash
# Check resource utilization
kubectl top pods -n microservices

# Analyze slow queries
kubectl logs -f deployment/database-service
```

#### Network Connectivity

```bash
# Test service-to-service communication
kubectl exec -it frontend-pod -- curl http://user-service:8080/health

# Check network policies
kubectl get networkpolicies -n microservices
```

## Further Reading

- [Microservices Architecture Patterns](https://microservices.io/patterns/)
- [WASM Component Model](https://component-model.bytecodealliance.org/)
- [Container Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Observability Engineering](https://www.oreilly.com/library/view/observability-engineering/9781492076438/)
- [Site Reliability Engineering](https://sre.google/books/)
