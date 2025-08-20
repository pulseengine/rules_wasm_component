#ifndef SIMPLE_CONSUMER_H
#define SIMPLE_CONSUMER_H

#include <foundation.h>         // Cross-package header - THE CRITICAL TEST!
#include <foundation_types.hpp> // Different extension
#include <string>

namespace test_consumer {
    class SimpleConsumer {
    public:
        SimpleConsumer();
        std::string testFoundation();
    };
}

#endif