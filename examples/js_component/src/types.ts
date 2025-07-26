// TypeScript type definitions for the calculator component

export interface Operation {
    op: 'add' | 'subtract' | 'multiply' | 'divide';
    a: number;
    b: number;
}

export interface CalculationResult {
    success: boolean;
    error: string | null;
    result: number | null;
}

export interface ComponentInfo {
    name: string;
    version: string;
    supportedOperations: string[];
}