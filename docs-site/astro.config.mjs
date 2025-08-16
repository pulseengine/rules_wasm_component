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
				// Map languages for better syntax highlighting
				langs: ['python', 'rust', 'go', 'javascript', 'typescript', 'bash', 'yaml', 'json', 'dockerfile']
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
					label: 'Getting Started',
					items: [
						{ label: 'Quick Start', slug: 'getting-started' },
						{ label: 'Installation', slug: 'installation' },
						{ label: 'First Component', slug: 'first-component' },
					],
				},
				{
					label: 'Architecture',
					items: [
						{ label: 'Overview', slug: 'architecture/overview' },
						{ label: 'Development Workflow', slug: 'workflow/development-flow' },
					],
				},
				{
					label: 'Tutorials',
					items: [
						{ label: 'Guided Rust Walkthrough', slug: 'tutorials/rust-guided-walkthrough' },
						{ label: 'Guided Go (TinyGo) Walkthrough', slug: 'tutorials/go-guided-walkthrough' },
					],
				},
				{
					label: 'Languages',
					items: [
						{ label: 'Rust Components', slug: 'languages/rust' },
						{ label: 'Go Components', slug: 'languages/go' },
					],
				},
				{
					label: 'Examples',
					items: [
						{ label: 'Basic Component', slug: 'examples/basic' },
					],
				},
				{
					label: 'Composition',
					items: [
						{ label: 'WAC Composition', slug: 'composition/wac' },
						{ label: 'WAC + OCI Integration', slug: 'composition/wac-oci-integration' },
					],
				},
				{
					label: 'Security',
					items: [
						{ label: 'Component Signing', slug: 'security/component-signing' },
					],
				},
				{
					label: 'Production',
					items: [
						{ label: 'Deployment Guide', slug: 'production/deployment-guide' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'Rule Reference', slug: 'reference/rules' },
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
