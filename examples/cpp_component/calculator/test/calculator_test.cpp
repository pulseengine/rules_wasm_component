#include "../src/calculator.h"
#include "../src/calculator_c.h"
#include <iostream>
#include <vector>
#include <cassert>
#include <cmath>

// Test framework (simple assertions)
#define ASSERT_TRUE(condition) do { \
    if (!(condition)) { \
        std::cerr << "ASSERTION FAILED: " << #condition << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
        exit(1); \
    } \
} while(0)

#define ASSERT_FALSE(condition) ASSERT_TRUE(!(condition))
#define ASSERT_EQ(expected, actual) ASSERT_TRUE((expected) == (actual))
#define ASSERT_DOUBLE_EQ(expected, actual) ASSERT_TRUE(std::abs((expected) - (actual)) < 1e-10)

class CalculatorTest {
public:
    void run_all_tests() {
        std::cout << "Running C++ Calculator Tests..." << std::endl;
        test_cpp_basic_operations();
        test_cpp_advanced_operations();
        test_cpp_batch_operations();
        test_cpp_error_handling();
        test_cpp_component_info();
        
        std::cout << "Running C Calculator Tests..." << std::endl;
        test_c_basic_operations();
        test_c_advanced_operations();
        test_c_batch_operations();
        test_c_error_handling();
        test_c_component_info();
        
        std::cout << "All tests passed!" << std::endl;
    }

private:
    // C++ Tests
    void test_cpp_basic_operations() {
        calculator::Calculator calc;
        
        // Test addition
        ASSERT_DOUBLE_EQ(5.0, calc.add(2.0, 3.0));
        ASSERT_DOUBLE_EQ(0.0, calc.add(-2.0, 2.0));
        
        // Test subtraction
        ASSERT_DOUBLE_EQ(1.0, calc.subtract(3.0, 2.0));
        ASSERT_DOUBLE_EQ(-1.0, calc.subtract(2.0, 3.0));
        
        // Test multiplication
        ASSERT_DOUBLE_EQ(6.0, calc.multiply(2.0, 3.0));
        ASSERT_DOUBLE_EQ(0.0, calc.multiply(0.0, 5.0));
        
        std::cout << "  ✓ C++ Basic operations tests passed" << std::endl;
    }
    
    void test_cpp_advanced_operations() {
        calculator::Calculator calc;
        
        // Test division
        auto div_result = calc.divide(6.0, 2.0);
        ASSERT_TRUE(div_result.success);
        ASSERT_DOUBLE_EQ(3.0, div_result.result.value());
        
        // Test division by zero
        auto div_zero = calc.divide(5.0, 0.0);
        ASSERT_FALSE(div_zero.success);
        ASSERT_TRUE(div_zero.error.has_value());
        
        // Test power
        auto pow_result = calc.power(2.0, 3.0);
        ASSERT_TRUE(pow_result.success);
        ASSERT_DOUBLE_EQ(8.0, pow_result.result.value());
        
        // Test square root
        auto sqrt_result = calc.sqrt(9.0);
        ASSERT_TRUE(sqrt_result.success);
        ASSERT_DOUBLE_EQ(3.0, sqrt_result.result.value());
        
        // Test factorial
        auto fact_result = calc.factorial(5);
        ASSERT_TRUE(fact_result.success);
        ASSERT_DOUBLE_EQ(120.0, fact_result.result.value());
        
        std::cout << "  ✓ C++ Advanced operations tests passed" << std::endl;
    }
    
    void test_cpp_batch_operations() {
        calculator::Calculator calc;
        
        std::vector<calculator::Calculator::Operation> operations = {
            {calculator::Calculator::OperationType::Add, 2.0, 3.0},
            {calculator::Calculator::OperationType::Multiply, 4.0, 5.0},
            {calculator::Calculator::OperationType::Sqrt, 16.0, std::nullopt}
        };
        
        auto results = calc.calculate_batch(operations);
        ASSERT_EQ(3, results.size());
        
        ASSERT_TRUE(results[0].success);
        ASSERT_DOUBLE_EQ(5.0, results[0].result.value());
        
        ASSERT_TRUE(results[1].success);
        ASSERT_DOUBLE_EQ(20.0, results[1].result.value());
        
        ASSERT_TRUE(results[2].success);
        ASSERT_DOUBLE_EQ(4.0, results[2].result.value());
        
        std::cout << "  ✓ C++ Batch operations tests passed" << std::endl;
    }
    
    void test_cpp_error_handling() {
        calculator::Calculator calc;
        
        // Test invalid inputs
        ASSERT_TRUE(std::isnan(calc.add(NAN, 5.0)));
        ASSERT_TRUE(std::isnan(calc.multiply(INFINITY, 2.0)));
        
        // Test square root of negative number
        auto sqrt_neg = calc.sqrt(-4.0);
        ASSERT_FALSE(sqrt_neg.success);
        
        // Test factorial of large number
        auto fact_large = calc.factorial(25);
        ASSERT_FALSE(fact_large.success);
        
        std::cout << "  ✓ C++ Error handling tests passed" << std::endl;
    }
    
    void test_cpp_component_info() {
        calculator::Calculator calc;
        
        auto info = calc.get_calculator_info();
        ASSERT_EQ("C++ Calculator Component", info.name);
        ASSERT_EQ("1.0.0", info.version);
        ASSERT_TRUE(info.supported_operations.size() > 0);
        
        // Test constants
        ASSERT_DOUBLE_EQ(M_PI, calc.get_pi());
        ASSERT_DOUBLE_EQ(M_E, calc.get_e());
        
        std::cout << "  ✓ C++ Component info tests passed" << std::endl;
    }
    
    // C Tests
    void test_c_basic_operations() {
        // Test addition
        ASSERT_DOUBLE_EQ(5.0, calculator_c_add(2.0, 3.0));
        ASSERT_DOUBLE_EQ(0.0, calculator_c_add(-2.0, 2.0));
        
        // Test subtraction
        ASSERT_DOUBLE_EQ(1.0, calculator_c_subtract(3.0, 2.0));
        ASSERT_DOUBLE_EQ(-1.0, calculator_c_subtract(2.0, 3.0));
        
        // Test multiplication
        ASSERT_DOUBLE_EQ(6.0, calculator_c_multiply(2.0, 3.0));
        ASSERT_DOUBLE_EQ(0.0, calculator_c_multiply(0.0, 5.0));
        
        std::cout << "  ✓ C Basic operations tests passed" << std::endl;
    }
    
    void test_c_advanced_operations() {
        // Test division
        calculation_result_t div_result = calculator_c_divide(6.0, 2.0);
        ASSERT_TRUE(div_result.success);
        ASSERT_DOUBLE_EQ(3.0, div_result.result);
        calculator_c_free_result(&div_result);
        
        // Test division by zero
        calculation_result_t div_zero = calculator_c_divide(5.0, 0.0);
        ASSERT_FALSE(div_zero.success);
        ASSERT_TRUE(div_zero.error != NULL);
        calculator_c_free_result(&div_zero);
        
        // Test power
        calculation_result_t pow_result = calculator_c_power(2.0, 3.0);
        ASSERT_TRUE(pow_result.success);
        ASSERT_DOUBLE_EQ(8.0, pow_result.result);
        calculator_c_free_result(&pow_result);
        
        // Test square root
        calculation_result_t sqrt_result = calculator_c_sqrt(9.0);
        ASSERT_TRUE(sqrt_result.success);
        ASSERT_DOUBLE_EQ(3.0, sqrt_result.result);
        calculator_c_free_result(&sqrt_result);
        
        // Test factorial
        calculation_result_t fact_result = calculator_c_factorial(5);
        ASSERT_TRUE(fact_result.success);
        ASSERT_DOUBLE_EQ(120.0, fact_result.result);
        calculator_c_free_result(&fact_result);
        
        std::cout << "  ✓ C Advanced operations tests passed" << std::endl;
    }
    
    void test_c_batch_operations() {
        operation_t operations[] = {
            {OP_ADD, 2.0, 3.0, true},
            {OP_MULTIPLY, 4.0, 5.0, true},
            {OP_SQRT, 16.0, 0.0, false}
        };
        
        size_t result_count;
        calculation_result_t* results = calculator_c_calculate_batch(operations, 3, &result_count);
        
        ASSERT_EQ(3, result_count);
        ASSERT_TRUE(results != NULL);
        
        ASSERT_TRUE(results[0].success);
        ASSERT_DOUBLE_EQ(5.0, results[0].result);
        
        ASSERT_TRUE(results[1].success);
        ASSERT_DOUBLE_EQ(20.0, results[1].result);
        
        ASSERT_TRUE(results[2].success);
        ASSERT_DOUBLE_EQ(4.0, results[2].result);
        
        calculator_c_free_results(results, result_count);
        
        std::cout << "  ✓ C Batch operations tests passed" << std::endl;
    }
    
    void test_c_error_handling() {
        // Test invalid inputs
        ASSERT_TRUE(isnan(calculator_c_add(NAN, 5.0)));
        ASSERT_TRUE(isnan(calculator_c_multiply(INFINITY, 2.0)));
        
        // Test square root of negative number
        calculation_result_t sqrt_neg = calculator_c_sqrt(-4.0);
        ASSERT_FALSE(sqrt_neg.success);
        calculator_c_free_result(&sqrt_neg);
        
        // Test factorial of large number
        calculation_result_t fact_large = calculator_c_factorial(25);
        ASSERT_FALSE(fact_large.success);
        calculator_c_free_result(&fact_large);
        
        std::cout << "  ✓ C Error handling tests passed" << std::endl;
    }
    
    void test_c_component_info() {
        component_info_t info = calculator_c_get_info();
        
        ASSERT_TRUE(strcmp(info.name, "C Calculator Component") == 0);
        ASSERT_TRUE(strcmp(info.version, "1.0.0") == 0);
        ASSERT_TRUE(info.supported_operations_count > 0);
        
        // Test constants
        ASSERT_DOUBLE_EQ(M_PI, calculator_c_get_pi());
        ASSERT_DOUBLE_EQ(M_E, calculator_c_get_e());
        
        calculator_c_free_component_info(&info);
        
        std::cout << "  ✓ C Component info tests passed" << std::endl;
    }
};

int main() {
    CalculatorTest test;
    test.run_all_tests();
    return 0;
}