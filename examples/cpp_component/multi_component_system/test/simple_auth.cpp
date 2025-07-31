#include <string>
#include <cstdint>

// Simple C++ auth service for testing build
extern "C" {
    bool authenticate_user(const char* username, const char* password) {
        return true;  // Always succeed for testing
    }

    const char* get_user_session(const char* username) {
        return "test-session-123";
    }

    bool health_check() {
        return true;
    }
}
