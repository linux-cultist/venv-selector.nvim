# Changelog

All notable changes to this project will be documented in this file.

### 2026-01-19

- New README to help make it quicker to understand the plugin.

### 2025-09-30
- Minimum Neovim requirement raised to **0.11** due to adoption of the new
  `vim.lsp.config()` and `vim.lsp.enable()` methods used for configuring LSP
  servers.
  - If you haven't migrated yet, see: https://lugh.ch/switching-to-neovim-native-lsp.html

### 2025-09-01
- New documentation site launched: https://venvselector.homelab.today
  - The site is searchable and contains expanded documentation and examples.

### 2025-08-27
- Merged the `regexp` branch into `main`, incorporating ~9 months of improvements.
  - Users who prefer the previous behavior can continue using the `v1` branch (note: `v1` is not actively updated).

### 2025-08-26
- Added support for `mini-pick` as an alternative picker.
- Plugin can now be lazy loaded. Remove `lazy = false` from your `lazy.nvim`
  configuration to benefit from faster Neovim startup times.
  - README updated with a lazy-loading example that loads the plugin when
    opening Python files.

---

For full documentation (configuration options, examples, API reference, and
detailed search configuration) please see the docs site:
https://venvselector.homelab.today

You can also find configuration files and the default search definitions here:
https://github.com/linux-cultist/venv-selector.nvim/tree/main