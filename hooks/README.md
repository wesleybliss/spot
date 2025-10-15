# Git Hooks

This directory contains Git hooks for the Spot repository.

## Available Hooks

### pre-push

Runs before pushing any branch to ensure code quality:

1. **dart analyze** - Checks for code issues and linting errors
2. **dart test** - Runs all tests

If either command fails, the push is aborted.

## Installation

After cloning the repository, run:

```bash
./hooks/install.sh
```

This will copy the hooks to your `.git/hooks/` directory and make them executable.

## Manual Installation

If you prefer to install manually:

```bash
cp hooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

## Bypassing Hooks

If you need to bypass the pre-push hook (not recommended):

```bash
git push --no-verify
```

**Note:** Only bypass hooks if absolutely necessary, as they help maintain code quality.
