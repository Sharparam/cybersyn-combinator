# Cybersyn Combinator

A mod for Factorio that adds a special combinator for use with the [Project Cybersyn][cybersyn] mod.

## Usage

 1. Install mod
 2. Craft the new "Cybersyn constant combinator"
 3. Place it like you would a regular constant combinator
 4. Configure the signals in it
 5. Hook it up to a Cybernetic combinator from [the Project Cybersyn mod][cybersyn]
 6. You're done!

## Development

 1. Clone repo somewhere.
 2. Symlink to the `src` folder from your Factorio mods folder

    Linux example:

    ```sh
    ln -s ~/repos/github.com/Sharparam/cybersyn-combinator/src ~/factorio/mods/cybersyn-combinator
    ```

    Windows example (powershell):

    ```pwsh
    New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\factorio\mods\cybersyn-combinator" -Value "$env:USERPROFILE\repos\github.com\Sharparam\cybersyn-combinator\src"
    ```
  3. Open the repo folder in VS Code or your favourite editor
  4. Hack away!

There is a [known issue about the Factorio modding extension for VS Code not being portable][fmtk-portable], so for now there are some non-portable entries in `.vscode/settings.json`.
If you edit these, make sure to not check your changes into Git before pushing.
(There are some other settings in there that *should* be shared, which is why the entire file is not ignored in `.gitignore`, pending a better way to structure things&hellip;)

## Testing

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

## Building/Packaging

The `bin/build` script can be used to package a zip of the mod. Run `./bin/build -h` for help on the available options.

For the common operation of packaging to a zip and removing any intermediate build files, run `./bin/build -vc` (`-v` enables verbose, and `-c` enables cleaning up intermediate files).

## Acknowledgements

A lot was gained from looking at how the [LTN Combinator Modernized][ltnc] mod does things, so big thanks are due to that mod for getting up and running with the Cybersyn version.

## License

Copyright © 2023 by [Adam Hellberg][sharparam].

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

[sharparam]: https://sharparam.com
[cybersyn]: https://mods.factorio.com/mod/cybersyn
[ltnc]: https://mods.factorio.com/mod/LTN_Combinator_Modernized
[fmtk-portable]: https://github.com/justarandomgeek/vscode-factoriomod-debug/issues/84
[busted]: https://github.com/lunarmodules/busted
[luarocks]: https://luarocks.org/
[moonscript]: https://moonscript.org/
