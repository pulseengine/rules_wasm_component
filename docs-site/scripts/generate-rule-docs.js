#!/usr/bin/env node

/**
 * Rule Documentation Generator
 * 
 * Converts JSON rule schemas from the Bazel project into Markdown format
 * suitable for the Astro Starlight documentation site.
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Configuration
const REPO_ROOT = path.resolve(__dirname, '../../');
const DOCS_OUTPUT_DIR = path.resolve(__dirname, '../src/content/docs/reference/');
const SCHEMA_GENERATOR_TARGET = '//tools/generate_schemas:generate_schemas';

/**
 * Generate fresh schema JSON from Bazel
 */
function generateSchemaJson() {
    console.log('🔧 Generating fresh rule schemas from Bazel...');
    
    try {
        const result = execSync(`cd "${REPO_ROOT}" && bazel run ${SCHEMA_GENERATOR_TARGET}`, {
            encoding: 'utf-8',
            stdio: ['pipe', 'pipe', 'pipe']
        });
        
        return JSON.parse(result);
    } catch (error) {
        console.error('❌ Failed to generate schemas:', error.message);
        
        // Fallback: try to use existing schema file
        const fallbackPath = path.join(REPO_ROOT, 'docs/rule_schemas.json');
        if (fs.existsSync(fallbackPath)) {
            console.log('📄 Using existing schema file as fallback...');
            return JSON.parse(fs.readFileSync(fallbackPath, 'utf-8'));
        }
        
        throw error;
    }
}

/**
 * Convert attribute type to human-readable format
 */
function formatAttributeType(type) {
    const typeMap = {
        'label': 'Label',
        'label_list': 'List of Labels',
        'string': 'String',
        'string_list': 'List of Strings',
        'string_dict': 'String Dictionary',
        'bool': 'Boolean',
        'int': 'Integer',
        'depset': 'Depset'
    };
    
    return typeMap[type] || type;
}

/**
 * Generate markdown for a single rule
 */
function generateRuleMarkdown(ruleName, ruleData) {
    const lines = [];
    
    // Title and description
    lines.push(`### ${ruleName}`);
    lines.push('');
    lines.push(ruleData.description);
    lines.push('');
    
    // Load statement
    if (ruleData.load_from) {
        lines.push('**Load from:**');
        lines.push('```python');
        lines.push(`load("${ruleData.load_from}", "${ruleName}")`);
        lines.push('```');
        lines.push('');
    }
    
    // Attributes (for rules) or Fields (for providers)
    if (ruleData.attributes) {
        lines.push('**Attributes:**');
        lines.push('');
        
        // Create table
        lines.push('| Name | Type | Required | Description |');
        lines.push('|------|------|----------|-------------|');
        
        Object.entries(ruleData.attributes).forEach(([attrName, attrData]) => {
            const type = formatAttributeType(attrData.type);
            const required = attrData.required ? '✅' : '❌';
            const description = attrData.description.replace(/\|/g, '\\|'); // Escape pipes
            
            let typeCell = type;
            if (attrData.default) {
                typeCell += `<br/>*Default: ${attrData.default}*`;
            }
            if (attrData.allowed_values && attrData.allowed_values.length > 0) {
                typeCell += `<br/>*Values: ${attrData.allowed_values.join(', ')}*`;
            }
            
            lines.push(`| \`${attrName}\` | ${typeCell} | ${required} | ${description} |`);
        });
        lines.push('');
    }
    
    if (ruleData.fields) {
        lines.push('**Provider Fields:**');
        lines.push('');
        
        // Create table
        lines.push('| Field | Type | Description |');
        lines.push('|-------|------|-------------|');
        
        Object.entries(ruleData.fields).forEach(([fieldName, fieldData]) => {
            const type = formatAttributeType(fieldData.type);
            const description = fieldData.description.replace(/\|/g, '\\|'); // Escape pipes
            
            lines.push(`| \`${fieldName}\` | ${type} | ${description} |`);
        });
        lines.push('');
    }
    
    // Examples
    if (ruleData.examples && ruleData.examples.length > 0) {
        lines.push('**Examples:**');
        lines.push('');
        
        ruleData.examples.forEach((example, index) => {
            if (ruleData.examples.length > 1) {
                lines.push(`#### ${example.title || `Example ${index + 1}`}`);
                lines.push('');
            }
            
            if (example.description) {
                lines.push(example.description);
                lines.push('');
            }
            
            lines.push('```python');
            lines.push(example.code);
            lines.push('```');
            lines.push('');
        });
    }
    
    return lines.join('\n');
}

/**
 * Generate the complete rule reference markdown
 */
function generateRuleReference(schemas) {
    const lines = [];
    
    // Frontmatter
    lines.push('---');
    lines.push('title: Rule Reference');
    lines.push('description: Complete reference for all WebAssembly Component Model Bazel rules');
    lines.push('---');
    lines.push('');
    
    // Introduction
    lines.push('# Rule Reference');
    lines.push('');
    lines.push('Complete reference documentation for all Bazel rules provided by rules_wasm_component.');
    lines.push('');
    lines.push('> **Note:** This documentation is automatically generated from rule definitions in the source code.');
    lines.push('> For the most up-to-date information, see the [source repository](https://github.com/pulseengine/rules_wasm_component).');
    lines.push('');
    
    // Categorize rules
    const categories = {
        'WIT & Interface Rules': [],
        'Component Rules': [],
        'Composition Rules': [],
        'Providers': [],
        'Other Rules': []
    };
    
    Object.entries(schemas).forEach(([name, data]) => {
        if (data.type === 'provider') {
            categories['Providers'].push({ name, data });
        } else if (name.includes('wit_')) {
            categories['WIT & Interface Rules'].push({ name, data });
        } else if (name.includes('wasm_component') || name.includes('rust_') || name.includes('go_') || name.includes('js_') || name.includes('cpp_')) {
            categories['Component Rules'].push({ name, data });
        } else if (name.includes('wac_') || name.includes('compose')) {
            categories['Composition Rules'].push({ name, data });
        } else {
            categories['Other Rules'].push({ name, data });
        }
    });
    
    // Generate table of contents
    lines.push('## Table of Contents');
    lines.push('');
    Object.entries(categories).forEach(([categoryName, items]) => {
        if (items.length > 0) {
            lines.push(`- [${categoryName}](#${categoryName.toLowerCase().replace(/[^a-z0-9]+/g, '-')})`);
            items.forEach(({ name }) => {
                lines.push(`  - [${name}](#${name.toLowerCase()})`);
            });
        }
    });
    lines.push('');
    
    // Generate rule documentation by category
    Object.entries(categories).forEach(([categoryName, items]) => {
        if (items.length > 0) {
            lines.push(`## ${categoryName}`);
            lines.push('');
            
            items.forEach(({ name, data }) => {
                lines.push(generateRuleMarkdown(name, data));
            });
        }
    });
    
    return lines.join('\n');
}

/**
 * Main execution
 */
function main() {
    console.log('📚 Generating Rule Reference Documentation...');
    
    try {
        // Generate schema JSON
        const schemas = generateSchemaJson();
        console.log(`✅ Loaded ${Object.keys(schemas).length} rule definitions`);
        
        // Generate markdown
        const markdown = generateRuleReference(schemas);
        
        // Ensure output directory exists
        if (!fs.existsSync(DOCS_OUTPUT_DIR)) {
            fs.mkdirSync(DOCS_OUTPUT_DIR, { recursive: true });
        }
        
        // Write output
        const outputPath = path.join(DOCS_OUTPUT_DIR, 'rules.mdx');
        fs.writeFileSync(outputPath, markdown, 'utf-8');
        
        console.log(`📖 Generated rule reference: ${outputPath}`);
        console.log(`📊 Documented ${Object.keys(schemas).length} rules and providers`);
        
    } catch (error) {
        console.error('❌ Error generating documentation:', error.message);
        process.exit(1);
    }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
    main();
}

export { generateRuleReference, generateSchemaJson };