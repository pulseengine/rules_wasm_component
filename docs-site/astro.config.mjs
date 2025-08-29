// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import path from 'path';
import { fileURLToPath } from 'url';
import mermaid from 'astro-mermaid';

// https://astro.build/config
export default defineConfig({
	site: 'https://rules_wasm_component.pulseengine.eu',
	vite: {
		resolve: {
			alias: {
				'@components': path.resolve(path.dirname(fileURLToPath(import.meta.url)), './src/components'),
			},
		},
	},
	integrations: [
		mermaid(),
		starlight({
			title: 'WebAssembly Component Rules',
			description: 'Modern Bazel rules for building and composing WebAssembly components',
			expressiveCode: {
				themes: ['github-dark', 'github-light'],
				// Use Python grammar for Starlark since Starlark syntax is a subset of Python
				shiki: {
					langAlias: {
						'starlark': 'python',
						'star': 'python',
						'bzl': 'python',
						'bazel': 'python'
					}
				}
			},
			social: [
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/pulseengine/rules_wasm_component',
				},
			],
			editLink: {
				baseUrl: 'https://github.com/pulseengine/rules_wasm_component/edit/main/docs-site/',
			},
			sidebar: [
				{
					label: 'GET STARTED',
					items: [
						{ label: '👋 Pick Your Learning Path', slug: 'pick-your-path' },
						{ label: 'Zero to Component in 2 Minutes', slug: 'zero-to-component' },
						{ label: 'Installation & Setup', slug: 'installation' },
					],
				},
				{
					label: 'LEARN',
					items: [
						{ label: 'WebAssembly Component Fundamentals', slug: 'learn/fundamentals' },
						{ label: 'Component Architecture', slug: 'architecture/overview' },
						{ label: 'Multi-Language Development', slug: 'guides/wit-bindgen-interface-mapping' },
						{ label: 'Tutorials', collapsed: true, items: [
							{ label: 'Code Explained Line by Line', slug: 'tutorials/code-explained' },
							{ label: 'First Component Tutorial', slug: 'first-component' },
							{ label: 'Guided Rust Walkthrough', slug: 'tutorials/rust-guided-walkthrough' },
							{ label: 'Guided Go (TinyGo) Walkthrough', slug: 'tutorials/go-guided-walkthrough' },
						]},
					],
				},
				{
					label: 'BUILD',
					items: [
						{ label: 'Language Development', collapsed: false, items: [
							{ label: 'Rust Components', slug: 'languages/rust' },
							{ label: 'Go Components', slug: 'languages/go' },
							{ label: 'JavaScript & TypeScript', slug: 'languages/javascript' },
							{ label: 'C & C++', slug: 'languages/cpp' },
						]},
						{ label: 'Common Patterns', collapsed: true, items: [
							{ label: 'WIT Bindgen Interface Mapping', slug: 'guides/wit-bindgen-interface-mapping' },
							{ label: 'WIT Bindgen Advanced Concepts', slug: 'guides/wit-bindgen-advanced-concepts' },
							{ label: 'Guest vs Native-Guest Bindings', slug: 'guides/host-vs-wasm-bindings' },
							{ label: 'Performance Optimization', slug: 'production/performance' },
							{ label: 'Advanced Features', slug: 'guides/advanced-features' },
						]},
						{ label: 'Examples', collapsed: true, items: [
							{ label: 'Basic Component', slug: 'examples/basic' },
							{ label: 'Basic Examples', slug: 'examples/basic-examples' },
							{ label: 'Intermediate Examples', slug: 'examples/intermediate-examples' },
							{ label: 'Advanced Examples', slug: 'examples/advanced-examples' },
							{ label: 'WIT Bindgen Interface Mapping', slug: 'examples/wit-bindgen-with-mappings' },
							{ label: 'Calculator (C++)', slug: 'examples/calculator' },
							{ label: 'HTTP Service (Go)', slug: 'examples/http-service' },
							{ label: 'Multi-Language System', slug: 'examples/multi-language' },
						]},
						{ label: 'Composition & Deployment', collapsed: true, items: [
							{ label: 'WAC Composition', slug: 'composition/wac' },
							{ label: 'WAC + OCI Integration', slug: 'composition/wac-oci-integration' },
							{ label: 'OCI Publishing', slug: 'production/publishing' },
							{ label: 'Deployment Guide', slug: 'production/deployment-guide' },
							{ label: 'Component Signing', slug: 'security/component-signing' },
							{ label: 'OCI Component Signing', slug: 'security/oci-signing' },
						]},
						{ label: 'Configuration & Tooling', collapsed: true, items: [
							{ label: 'Toolchain Configuration', slug: 'guides/toolchain-configuration' },
							{ label: 'Multi-Profile Builds', slug: 'guides/multi-profile-builds' },
							{ label: 'External WIT Dependencies', slug: 'guides/external-wit-dependencies' },
							{ label: 'Migration Guide', slug: 'guides/migration' },
							{ label: 'Development Workflow', slug: 'workflow/development-flow' },
						]},
						{ label: 'Troubleshooting', collapsed: true, items: [
							{ label: 'Common Issues & Solutions', slug: 'troubleshooting/common-issues' },
							{ label: 'Export Macro Visibility', slug: 'troubleshooting/export-macro-visibility' },
							{ label: 'WIT Bindgen Troubleshooting', slug: 'guides/wit-bindgen-troubleshooting' },
						]},
					],
				},
				{
					label: 'REFERENCE',
					items: [
						{ label: 'WIT & Interface Rules', slug: 'reference/wit-interface-rules' },
						{ label: 'Language Rules', slug: 'reference/language-rules' },
						{ label: 'Composition Rules', slug: 'reference/composition-rules' },
						{ label: 'Security Rules', slug: 'reference/security-rules' },
						{ label: 'Complete Rule Reference', slug: 'reference/rules' },
					],
				},
			],
			customCss: [
				'./src/styles/custom.css',
			],
			head: [
				{
					tag: 'script',
					content: `
// Diagram modal functionality
document.addEventListener('DOMContentLoaded', function() {
  // Create modal HTML
  const modalHTML = \`
    <div id="diagramModal" class="diagram-modal">
      <span class="modal-close">&times;</span>
      <div id="modalContent"></div>
    </div>
  \`;
  document.body.insertAdjacentHTML('beforeend', modalHTML);

  const modal = document.getElementById('diagramModal');
  const modalContent = document.getElementById('modalContent');
  const closeBtn = document.querySelector('.modal-close');

  function addClickListeners() {
    const diagrams = document.querySelectorAll('svg[id^="mermaid-"]');
    diagrams.forEach(diagram => {
      diagram.style.cursor = 'pointer';
      diagram.addEventListener('click', function() {
        const clone = this.cloneNode(true);
        modalContent.innerHTML = '';
        modalContent.appendChild(clone);
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
      });
    });
  }

  function closeModal() {
    modal.classList.remove('active');
    document.body.style.overflow = '';
    modalContent.innerHTML = '';
  }

  if (closeBtn) {
    closeBtn.addEventListener('click', closeModal);
  }

  if (modal) {
    modal.addEventListener('click', function(e) {
      if (e.target === modal) closeModal();
    });
  }

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && modal && modal.classList.contains('active')) {
      closeModal();
    }
  });

  addClickListeners();

  // Re-add listeners after navigation
  document.addEventListener('astro:page-load', addClickListeners);
});
					`,
				},
			],
		}),
	],
});
