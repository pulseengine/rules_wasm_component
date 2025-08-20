#ifndef MATH_H  
#define MATH_H

#include "foundation.h"      // Cross-package include
#include "foundation_types.hpp"  // Different extension

namespace math {
    double add(double a, double b);
    foundation::Config getConfig();
}

#endif