# neotest-jest

This plugin provides a vitest adapter for the [Neotest](https://github.com/rcarriga/neotest) framework.

This plugin is a fork of [neotest-jest](https://github.com/haydenmeade/neotest-jest), credit to 'haydenmeade' where appropriate, this simply adapts the work done in the 'neotest-jest' repository to work with vitest and its slightly different json reporter.

## Installation

Using packer:

```lua
use({
  'rcarriga/neotest',
  requires = {
    ...,
    'KaiSpencer/neotest-vitest',
  }
  config = function()
    require('neotest').setup({
      ...,
      adapters = {
        require('neotest-vitest'),
      }
    })
  end
})
```

## Usage

See neotest's documentation for more information on how to run tests.

