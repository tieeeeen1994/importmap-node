# Importmap Node

A Rails gem that bridges **Yarn** package management with Rails' [importmap](https://github.com/rails/importmap-rails) asset pipeline. Install npm packages via Yarn, automatically vendor the compiled JS entry point into `vendor/javascript/`, and add a `pin` to `config/importmap.rb` — all in one command.

No bundler (webpack, esbuild, etc.) required.

## Requirements

- Ruby >= 3.1
- Rails >= 7.0
- [Yarn](https://yarnpkg.com/) available on `$PATH`
- An existing `config/importmap.rb` (i.e. your app already uses `importmap-rails`)

## Installation

Add to your `Gemfile`:

```ruby
gem "importmap-node"
```

Then run:

```sh
bundle install
```

## Usage

### Install a package

```sh
rails importmap:node:install[lodash]
```

This will:

1. Run `yarn add lodash`
2. Find the package's JS entry point from `node_modules/lodash/package.json`
3. Copy it to `vendor/javascript/`
4. Append a `pin "lodash", to: "lodash.js"` line to `config/importmap.rb`
5. Record the package in `config/importmap_node.json` for future updates

### Install from a Git repository

You can install packages directly from GitHub or any Git URL:

```sh
# GitHub shorthand (user/repo)
rails importmap:node:install[tieeeeen1994/app-modal]

# Full HTTPS URL
rails importmap:node:install[https://github.com/tieeeeen1994/app-modal]

# Specific branch, tag, or commit
rails importmap:node:install[tieeeeen1994/app-modal#main]

# Explicit prefix variants
rails importmap:node:install[github:tieeeeen1994/app-modal]
rails importmap:node:install[git+https://github.com/tieeeeen1994/app-modal]
```

The real package name is automatically resolved from the repository's `package.json` after Yarn installs it.

### Install a local package

```sh
rails importmap:node:install[file:../my-lib]
```

The real package name is read from the local `package.json` and the package is installed as `<name>@file:<path>`.

### Remove a package

```sh
rails importmap:node:remove[lodash]
```

This will:

1. Run `yarn remove lodash`
2. Delete the vendored file from `vendor/javascript/`
3. Remove the `pin` line from `config/importmap.rb`
4. Remove the entry from `config/importmap_node.json`

### Update all packages

```sh
rails importmap:node:update
```

Re-runs `yarn up` for all packages tracked in `config/importmap_node.json`, then re-vendors and re-pins each one.

## How it works

The gem maintains a `config/importmap_node.json` file that records all managed package specs. On each install, only the **single JS entry point** of a package (resolved via the `module` → `main` → `index.js` fields in `package.json`) is copied into `vendor/javascript/`. Transitive dependencies and non-JS assets are not vendored.

```
config/importmap_node.json   — tracks installed package specs
config/importmap.rb          — pin lines are added/removed here
vendor/javascript/           — vendored JS entry-point files land here
```

## Programmatic API

```ruby
installer = Importmap::Node::Installer.new             # uses Rails.root
installer = Importmap::Node::Installer.new(root: "/path/to/app")

installer.install("lodash")    # install & vendor a package
installer.uninstall("lodash")  # remove & unvendor a package
installer.update               # update all tracked packages
```

## License

[MIT](LICENSE)
