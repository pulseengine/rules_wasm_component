#pragma once

#include "minimal_math.h"

extern "C" {

// Exported WIT interface implementations
double minimal_math_sqrt(double x);
double minimal_math_pow(double base, double exp);
double minimal_math_sin(double x);
double minimal_math_cos(double x);

}
