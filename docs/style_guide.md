## Style guide

### Naming conventions
- All functions, variables, constants, custom uniforms and files should be named
  in `snake_case`.
- Structs should be named in `PascalCase`.
- Macros should be named in `SCREAMING_SNAKE_CASE` (There are some macros that
  pretend to be functions and are named like functions; going forward I think
  we should avoid this.)

### Code formatting
- Ideally, auto-format your code using `clang-format` before making a PR.
- Otherwise, just try to make it look like the other code (4-space indentation,
  80-char limit, etc. I periodically auto-format everything so it doesn't
  matter too much.)
