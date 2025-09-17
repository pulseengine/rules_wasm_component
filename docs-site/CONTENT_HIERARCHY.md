# Documentation Content Hierarchy

## Purpose

This document defines the clear content hierarchy for the docs-site to prevent duplication and ensure proper
cross-referencing between pages.

## Content Ownership Structure

### 1. Installation & Setup (Canonical Sources)

**Primary owner:** `/installation.md`

- Complete installation instructions for all platforms
- All language-specific setup (Rust, Go, C++, JavaScript)
- Toolchain configuration details
- Troubleshooting installation issues

**Secondary references:**

- `/getting-started.mdx` - Quick reference with link to full installation
- `/first-component.md` - Minimal setup with reference to installation guide
- Language-specific guides - Link to installation for setup details

**Pattern:** Other pages should provide minimal setup and reference `/installation.md` for details.

### 2. Tutorial Progression (Learning Path)

**Ultra-fast (2 min):** `/zero-to-component.mdx`

- Immediate success using existing examples
- Minimal explanation, maximum speed
- References detailed tutorials for understanding

**Quick hands-on (10 min):** `/first-component.md`

- Build from scratch step-by-step
- Focused on practical implementation
- References installation and detailed tutorials

**Complete understanding (30 min):** `/tutorials/rust-guided-walkthrough.mdx`

- Deep explanations of concepts and pipeline
- Line-by-line code analysis with diagrams
- Complete mental model building

**Technical reference:** `/tutorials/code-explained.mdx`

- Visual diagrams of component building process
- Progressive complexity with Mermaid diagrams
- Technical deep-dive into each file

### 3. Code Examples (Canonical Patterns)

**BUILD.bazel patterns:**

- **Owner:** `/examples/basic/` - Canonical Rust component pattern
- **Owner:** `/examples/calculator/` - Error handling pattern
- **Owner:** Language-specific examples - Language-specific patterns

**References:**

- Tutorial pages link to examples instead of duplicating BUILD.bazel code
- Rule reference shows usage patterns, examples show complete implementations

**WIT interface examples:**

- **Owner:** `/tutorials/code-explained.mdx` - Detailed WIT explanations
- **References:** Other pages link to detailed explanations rather than re-explaining

### 4. Advanced Topics (Specialized Ownership)

**Component Composition:**

- **Owner:** `/composition/wac/` - Complete WAC composition guide
- **References:** Getting started mentions composition, links to dedicated guide

**Performance Optimization:**

- **Owner:** `/production/performance/` - Wizer and optimization techniques
- **References:** Other pages mention performance, link to dedicated guide

**Security & Signing:**

- **Owner:** `/security/component-signing.mdx` - Complete security guide
- **References:** Brief mentions in other pages, links for details

### 5. Language-Specific Content

**Rust:** `/languages/rust/`
**Go:** `/languages/go/`
**C++:** `/languages/cpp/`
**JavaScript:** `/languages/javascript/`

**Pattern:** Each language guide owns its specific patterns and advanced features. Getting started provides overview,
language guides provide depth.

### 6. Reference Documentation

**Rule Reference:** `/reference/rules.mdx`

- **Owner:** Complete API documentation for all rules
- **Pattern:** Examples show usage, reference shows complete API

**Troubleshooting:** `/troubleshooting/common-issues.mdx`

- **Owner:** All error messages and solutions
- **Pattern:** Other pages reference troubleshooting for specific issues

## Content Cross-Reference Patterns

### ✅ Good Patterns

1. **Provide minimal context + link to canonical source**

   ```markdown
   For complete installation instructions, see the [Installation Guide](/installation/).

   Quick setup for Rust:
   [minimal code example]
   ```

2. **Use approach grids for different learning paths**

   ```html
   <div class="approach-grid">
     <div class="approach-card">
       <h3>🚀 Ultra-Fast (2 minutes)</h3>
       <p>Get working instantly</p>
       <a href="/zero-to-component/">Zero to Component →</a>
     </div>
   </div>
   ```

3. **Reference examples instead of duplicating BUILD.bazel**

   ```markdown
   For the complete BUILD.bazel pattern, see the [basic example](/examples/basic/).
   ```

### ❌ Anti-Patterns to Avoid

1. **Duplicating installation instructions**
   - ❌ Copy full MODULE.bazel setup across multiple pages
   - ✅ Provide minimal setup + link to installation guide

2. **Re-explaining WIT syntax**
   - ❌ Explain WIT syntax on every tutorial page
   - ✅ Link to detailed explanation in code-explained tutorial

3. **Duplicating BUILD.bazel examples**
   - ❌ Show complete BUILD.bazel on multiple pages
   - ✅ Show pattern summary + link to complete example

4. **Redundant troubleshooting**
   - ❌ Scatter error solutions across multiple pages
   - ✅ Centralize in troubleshooting guide + cross-reference

## Content Update Protocol

### When Adding New Content

1. **Check existing hierarchy** - Does this content fit an existing owner?
2. **Identify content type** - Tutorial, reference, example, or specialized guide?
3. **Assign ownership** - Which page should be the canonical source?
4. **Plan references** - How will other pages reference this content?

### When Updating Existing Content

1. **Identify the canonical owner** - Update the source of truth first
2. **Update references** - Ensure cross-references remain accurate
3. **Check for duplication** - Remove any content that duplicates the update

### Review Checklist

Before publishing content changes:

- [ ] Is this content duplicated elsewhere?
- [ ] Does this page properly reference canonical sources?
- [ ] Are cross-references accurate and helpful?
- [ ] Does this follow the established content hierarchy?
- [ ] Would a new user understand the learning progression?

## Maintenance

This hierarchy should be reviewed quarterly to:

- Identify new duplication that has crept in
- Update reference patterns as content evolves
- Ensure learning paths remain clear and progressive
- Consolidate content that has become scattered

## Success Metrics

- **No content duplication** - Same information shouldn't exist in multiple places
- **Clear learning paths** - Users can progress from beginner to advanced
- **Fast answers** - Users can quickly find what they need
- **Cross-references work** - Links lead to the right level of detail

This hierarchy ensures our documentation grows systematically while remaining maintainable and user-friendly.
