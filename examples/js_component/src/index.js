// Main entry point for the hello JavaScript component
import { formatMessage } from './utils.js';
import _ from 'lodash';

// Component implementation matching the WIT interface
export function sayHello(name) {
    const processedName = _.capitalize(name);
    return formatMessage(processedName);
}

export function greetMultiple(names) {
    return names.map(name => sayHello(name));
}

export function getComponentInfo() {
    return {
        name: "Hello JavaScript Component",
        version: "1.0.0",
        description: "A WebAssembly component built from JavaScript using jco",
        features: ["greeting", "batch-processing"]
    };
}