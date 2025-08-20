#ifndef FOUNDATION_TYPES_HPP
#define FOUNDATION_TYPES_HPP

#include <memory>

namespace foundation {
    template<typename T>
    using shared_ptr = std::shared_ptr<T>;
    
    struct Config {
        std::string name;
        int version;
    };
}

#endif