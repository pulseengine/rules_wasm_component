#include "math.h"

namespace math {
    double add(double a, double b) { return a + b; }
    foundation::Config getConfig() { 
        return foundation::Config{"math", 1}; 
    }
}