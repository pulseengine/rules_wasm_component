#include "simple_consumer.h"

namespace test_consumer {
    SimpleConsumer::SimpleConsumer() {
        foundation::initialize(); // Use cross-package function
    }
    
    std::string SimpleConsumer::testFoundation() {
        return "Foundation version: " + foundation::getVersion();
    }
}

// C exports for WIT
extern "C" {
    __attribute__((export_name("test-api#test-foundation")))
    char* test_foundation() {
        test_consumer::SimpleConsumer consumer;
        std::string result = consumer.testFoundation();
        char* ret = (char*)malloc(result.length() + 1);
        strcpy(ret, result.c_str());
        return ret;
    }
}