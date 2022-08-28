# neotest-vitest
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-2-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

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
        require('neotest-vitest')({
          vitestCommand = "npm test --",
          vitestConfigFile = "custom.vitest.config.ts",
        }),
      }
    })
  end
})
```

## Usage

See neotest's documentation for more information on how to run tests.

## Development

To trigger the tests for the adapter, run:

```sh
./scripts/test
```

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/shiradofu"><img src="https://avatars.githubusercontent.com/u/43514606?v=4?s=100" width="100px;" alt=""/><br /><sub><b>しらどふ</b></sub></a><br /><a href="https://github.com/KaiSpencer/neotest-vitest/commits?author=shiradofu" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/KaiSpencer"><img src="https://avatars.githubusercontent.com/u/51139521?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Kai Spencer</b></sub></a><br /><a href="https://github.com/KaiSpencer/neotest-vitest/commits?author=KaiSpencer" title="Code">💻</a> <a href="#maintenance-KaiSpencer" title="Maintenance">🚧</a> <a href="https://github.com/KaiSpencer/neotest-vitest/commits?author=KaiSpencer" title="Documentation">📖</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!