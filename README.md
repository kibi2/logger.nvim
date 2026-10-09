# logger.nvim

[![CI](https://github.com/kibi2/logger.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/kibi2/logger.nvim/actions)
[![codecov](https://codecov.io/gh/kibi2/logger.nvim/branch/main/graph/badge.svg)](https://codecov.io/gh/kibi2/logger.nvim)
![GitHub release](https://img.shields.io/github/v/release/kibi2/logger.nvim)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim)

A lightweight logging library for Neovim plugins.

**Work in progress.** The API and configuration may change.

## Features

- Log levels: `debug`, `info`, `warn`, and `error`
- Output to a Neovim buffer, a file, or standard output
- Structured log messages with timestamps and source locations
- Optional category-based logging with highlights
- Debugging helpers: `probe`, `watch`, `is_debug`, and `assert`

## Installation

Install `kibi2/logger.nvim` using your preferred Neovim plugin manager.

## Usage

```lua
local logger = require("kibi2.logger")

logger.debug("debug message")
logger.info("information")
logger.warn("warning")
logger.error("error")
```

## Configuration

Configuration options and defaults are still under development.

## License

MIT
