# Contributing to Keila

This document describes how to contribute code or translations to the Keila
project.

## Development Setup

Before you get started with developing Keila, you need to set up your development
environment.

### Setup with VS Code and [DevContainer](https://code.visualstudio.com/docs/remote/containers)
* Clone the repository:
  `git clone https://github.com/pentacent/keila.git`
* Install the [Remote Container](https://github.com/microsoft/vscode-dev-containers)
  extension in Visual Code
* Click on the ![Screenshot of DevContainer icon](.github/assets/devcontainer-button.png)
  icon in the bottom left corner and select `Reopen in Container` or look for
  `Reopen in Container` in the command panel (`Ctrl+Shift+P`)
* Wait for the containers to build and install all the dependencies needed to
  run Keila, including [PostgreSQL](https://www.postgresql.org/)
  and [Elixir](https://elixir-lang.org/install.html)
* Open a terminal from VS Code and proceed with the instructions from the
  [Run Keila](#run-keila) section

### Setup with other editors
Start by cloning the repository: `git clone https://github.com/pentacent/keila.git`

#### Install Dependencies
[Install Elixir](https://elixir-lang.org/install.html) on your machine and launch
an an instance of [PostgreSQL](https://www.postgresql.org/).

#### Run Keila

* Install dependencies with `mix deps.get`
* Install dependencies and set up the database with `mix setup`
* Start Keila server with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Contributing Code
Code contributions to Keila are welcome!

If you don’t know where to start, take a look at these [Good First Issues](https://github.com/pentacent/keila/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).

### Contribution Guidelines
Before you commit code to Keila, make sure to run `mix format` to ensure
consistent formatting.

### Contributor License Agreement (CLA)
Before we can accept your contribution, please sign the Contributor License Agreement (CLA).

Sign the CLA by running `./.cla/sign.sh` and following the instructions in the terminal.

Read here about how the CLA works: [CLA Readme](.cla/README.md)


## Translating Keila
Keila uses the [Gettext format](https://en.wikipedia.org/wiki/Gettext) for
translations of the interface.

Translation files are located in `priv/gettext`.

### Getting Started

Before you create a new translation or modify an existing translation, you need
to extract and update all strings from the code:
`mix gettext.extract --merge`

### Modify existing translations
Next you can use the editor of your choice to either edit the existing `.po`
files in `priv/gettext`. A convenient Open Source program for editing
translation files is [Poedit](https://poedit.net).

### Creating a new translation
1) Use the `.pot` templates in `priv/gettext` to create translation files for your
   language . New translations should be stored in
   `priv/gettext/:language/LC_MESSAGES`.

2) Find the line `config :keila, KeilaWeb.Gettext` in `config/config.exs` and
   add the language code of the new language to the `:locales` list.

3) Find the line `def available_locales() do` in `lib/keila_web/gettext.ex` and
   add a tuple with the native language name and the language code to the list
   returned by the function.

## Finalizing your changes
Run `mix gettext.merge priv/gettext` to compile your changes. Make sure to
commit all changes to `.pot`, `.po` and the compiled `.mo`.
