# CLAUDE.md - Guide for Claude working with this repository

## Commands
- Running bash scripts: `bash scriptname.bash`
- Running Python scripts: `python3 scriptname.py` 
- Create commit: `git add <files>; git commit -m "Commit message"`

## Coding Style Guidelines

### Bash Scripts
- Use `#!/bin/bash` or `#!/usr/bin/env bash` shebang
- Define PATH at the beginning of scripts
- Use functions for reusable code
- Include error handling with meaningful messages
- Exit codes: 0 for success, non-zero for errors
- Use clear variable names with descriptive comments
- Error function pattern: `eerror() { echo "$*"; exit 1; }`

### Python Scripts
- Use Python 3 with `#!/usr/bin/env python3` shebang
- Import organization: standard lib first, then third-party
- Follow PEP 8 guidelines for formatting
- Use descriptive variable and function names
- Include error handling with try/except blocks
- Command-line arguments: use argparse for CLI options
- Document functions with docstrings

### Repository Structure
- Active scripts in the root directory
- Outdated scripts in the `deprecated/` directory
- Each script should focus on a single task/functionality