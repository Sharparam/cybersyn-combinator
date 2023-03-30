# Contributing

We deeply appreciate anyone wanting to contribute to Cybersyn Combinator!

In order to make the code neat, readable, and organized properly, there are some guidelines and rules you must follow.

Always remember, if you are unsure about something: check the existing source to get an idea of how things should look!

If you have more specific questions about the guidelines or other things about the project, feel free to contact anyone listed under `PRIMARY AUTHORS` in the [AUTHORS][] file, [create an issue][new-issue] or [start a new discussion][new-discussion] in the [main repo][repo].

As anything related to this project, contributing is covered under the [Code of Conduct for Cybersyn Combinator][coc].

## Cloning the repo

First off, fork the repository and clone it to your local development system:

```sh
git clone git@github.com:<YOUR-USERNAME>/cybersyn-combinator.git
```

Or if you're not using SSH keys with GitHub:

```sh
git clone https://github.com/<YOUR-USERNAME>/cybersyn-combinator.git
```

To get the mod to load in your Factorio game, symlink the `src` folder in the repo as the mod folder:

Linux example:

```sh
ln -s ~/path/to/cybersyn-combinator/src ~/factorio/mods/cybersyn-combinator
```

Windows example (powershell):

```pwsh
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\factorio\mods\cybersyn-combinator" -Value "$env:USERPROFILE\path\to\cybersyn-combinator\src"
```

## Development environment

Install Lua 5.2.1 as that is what Factorio uses.

If you're using VS Code, it will suggest the necessary extensions to install when opening the project:
 - [sumneko.lua][sumneko-lua]
 - [Factorio Modding Tool Kit][fmtk]

There is a [known issue about the Factorio modding extension for VS Code not being portable][fmtk-portable], so for now there are some non-portable entries in `.vscode/settings.json`.
If you edit these, make sure to not check your changes into Git before pushing.
(There are some other settings in there that *should* be shared, which is why the entire file is not ignored in `.gitignore`, pending a better way to structure things&hellip;)

## Tests

There are some basic tests using [busted][] that you can run.
Simply run the `busted` command in the root of the repo.

If you don't have busted, you can install it using [LuaRocks][]:

```sh
luarocks install busted
```

The tests are written in [MoonScript][], so you will additionally need to install that:

```sh
luarocks install moonscript
```

## Migrations

Use the `bin/migrate` helper script to create a new Lua or JSON migration, any arguments passed to the script will be interpreted as the migration name.
Pass `-j` as the first argument to generate a JSON migration.

The new migration file will have the current date and time (in UTC) as a prefix, followed by the current version number as determined by `git describe`.

## Building/Packaging

The `bin/build` script can be used to package a zip of the mod. Run `./bin/build -h` for help on the available options.

For the common operation of packaging to a zip and removing any intermediate build files, run `./bin/build -vc` (`-v` enables verbose, and `-c` enables cleaning up intermediate files).

The resulting file(s) will be in the `build` folder at the root of the repository.

## Code formatting

There is an `.editorconfig` file in the repo that configures various Lua formatting rules that sumneko.lua will
look at when formatting code.
This should be sufficient to maintain proper style in the source code.

A basic rundown:

  - Indent with two spaces, not tabs.
  - Do not put trailing commas.
  - Use double quote marks (`"`) for strings rather than single (`'`).
  - You can call methods that take a single string or table without the parentheses, if you like.
    E.g.: `my_function "string argument"` or `my_function { table = "argument" }`
  - Variables are named with `snake_case`
  - Constants are named with `SCREAMING_SNAKE_CASE`
  - Classes are named with `PascalCase`
  - Enums are named with `PascalCase`
  - [Use annotations for Lua code][annotations]
  - Prefer modules over using the global namespace (`_G`/`_ENV`) (not to be confused with the `global` table)

If there are any questions regarding formatting or if you feel these instructions are lacking, please reach out using
the contact methods mentioned at the top of this document!

The most important part if you want to contribute is to get your ideas and code across so it can be reviewed by us.
If there are issues with formatting we will help you during the review process to fix them, so feel free to open
a pull request to discuss the code if your feature is done and you're just unsure about the formatting being
"up to code".

(You can also use GitHub's "Work in progress" feature on pull requests if you feel like there is more work to be done
before it's ready to merge, but you want to receive some input during the process.)

[repo]: https://github.com/Sharparam/cybersyn-combinator
[coc]: https://github.com/Sharparam/cybersyn-combinator/blob/main/.github/CODE_OF_CONDUCT.md
[authors]: https://github.com/Sharparam/cybersyn-combinator/blob/main/AUTHORS
[new-issue]: https://github.com/Sharparam/cybersyn-combinator/issues/new/choose
[new-discussion]: https://github.com/Sharparam/cybersyn-combinator/discussions/new/choose
[sumneko-lua]: https://marketplace.visualstudio.com/items?itemName=sumneko.lua
[fmtk]: https://marketplace.visualstudio.com/items?itemName=justarandomgeek.factoriomod-debug
[fmtk-portable]: https://github.com/justarandomgeek/vscode-factoriomod-debug/issues/84
[busted]: https://github.com/lunarmodules/busted
[luarocks]: https://luarocks.org/
[moonscript]: https://moonscript.org/
[annotations]: https://github.com/LuaLS/lua-language-server/wiki/Annotations
