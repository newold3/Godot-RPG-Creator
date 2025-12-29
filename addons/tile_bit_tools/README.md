![TileBitTools](https://raw.githubusercontent.com/dandeliondino/tile_bit_tools/main/assets/header.png)

TileBitTools is a Godot 4 plugin for autotile templates and terrain bit editing.

The terrain system in Godot 4 is powerful and extensible, and has a lot of untapped potential. The goal of this plugin is to enable fast iterations, to assist in migrating from Godot 3, and to speed up the learning process for new users.

*Click on the screenshots below to expand*

[![Animated gif demonstrating how to apply a template](https://raw.githubusercontent.com/dandeliondino/tile_bit_tools/main/assets/tutorials/apply_template_thumb.gif)](https://github.com/dandeliondino/tile_bit_tools/blob/main/assets/tutorials/apply_template.gif)
[![Screenshot of a built-in template](https://raw.githubusercontent.com/dandeliondino/tile_bit_tools/main/assets/tips_and_examples_thumb.png)](https://github.com/dandeliondino/tile_bit_tools/blob/main/assets/tips_and_examples.png)
[![Screenshot of the Save Template dialog window](https://raw.githubusercontent.com/dandeliondino/tile_bit_tools/main/assets/save_custom_templates_thumb.png)](https://github.com/dandeliondino/tile_bit_tools/blob/main/assets/save_custom_templates.png)
[![Screenshots of setting up a 3-terrain tileset](https://raw.githubusercontent.com/dandeliondino/tile_bit_tools/main/assets/terrain_transitions_thumb.png)](https://github.com/dandeliondino/tile_bit_tools/blob/main/assets/terrain_transitions.png)

## Features
- **Built-in autotile templates for all three Godot 4 terrain modes**
    - **3x3 minimal**, **3x3 16-tile** and **2x2** templates from Godot 3 documentation.
    - **Blob**, **Wang** and **Wang 3-terrain** templates to match Tilesetter's default export.
    - **Simple 9- and 4-tile** templates. These are modular corner-mode templates that match tile configurations commonly found in spritesheets.
- **Tips and example tiles for all built-in templates**
- **Terrain bit editing buttons** to make changes like 'Fill' and 'Clear' to multiple tiles or peering bits in one click
- **Custom user template creation**
    - Save new templates from the terrain peering bits on existing tiles. Statistics and previews are automatically generated.
    - Use as a quick way to copy-paste terrain bits.
    - Or use to save complex, reusable templates to a shared directory accessible to all projects.
- **Options in Project Settings**
    - Customize the template bit colors (default colors are from the color-blind-friendly 'bright' scheme from [Paul Tol](https://personal.sron.nl/~pault/))
    - Customize which messages appear in the Output log
    - Customize the template save folder location


## Limitations
- Even using Godot 3 autotile templates, tile placement will not work exactly the same as it did in Godot 3, as the core matching algorithm is different
- Hex and isometric tiles are not supported
- Alternative tiles are not supported


## How to use
*Please back up your project before making any changes. Godot 4 is still new, and TileBitTools is even newer, so unexpected behavior may occur.*

TileBitTools is located in the bottom TileSet editor, in the Select tab. To access any of its functions, the first step is to select tiles.

See the following pages for detailed directions:

- [Installation](https://github.com/dandeliondino/tile_bit_tools/wiki/1.-Installation)
- [Bulk terrain editing buttons](https://github.com/dandeliondino/tile_bit_tools/wiki/2.-Bulk-Terrain-Editing-Buttons)
- Templates
    - [Applying templates](https://github.com/dandeliondino/tile_bit_tools/wiki/3.1-Applying-Templates)
    - [Saving templates](https://github.com/dandeliondino/tile_bit_tools/wiki/3.2-Saving-Templates) - ***If you are saving a significant amount of data in your templates, please make sure they are being backed up and/or added to a version control system. There are rare cases of [template data being deleted on editor startup](https://github.com/dandeliondino/tile_bit_tools/issues/49).***
    - [Editing templates](https://github.com/dandeliondino/tile_bit_tools/wiki/3.3-Editing-Templates)
- [Warning regarding resource files](https://github.com/dandeliondino/tile_bit_tools/wiki/X.-Warning-Regarding-Resource-Files)


## Feedback
Find a bug? -> [Known Bugs and Reports](https://github.com/dandeliondino/tile_bit_tools/issues/2)

Have an autotile template that should be built-in? -> [Add More Built-in Terrain Templates](https://github.com/dandeliondino/tile_bit_tools/issues/4)

Have an idea for a new feature? -> [Future Directions and Suggestions](https://github.com/dandeliondino/tile_bit_tools/issues/3)


## Credits
Concept inspired by [Wareya's Godot Tile Setup Helper](https://github.com/wareya/godot-tile-setup-helper) for Godot 3.5

Huge thanks to [YuriSizov's Godot Editor Theme Explorer](https://github.com/YuriSizov/godot-editor-theme-explorer) and [Zylann's Editor Debugger](https://github.com/Zylann/godot_editor_debugger_plugin)

The example tilesets are adapted from [Kenney's Pixel Shmup](https://www.kenney.nl/assets/pixel-shmup) ([License: CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/))

The TileBitTools icon is modified from [Kenney's Game Icons](https://www.kenney.nl/assets/game-icons) ([License: CCO 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/))

The fonts in the header and images are [Lilita One](https://fonts.google.com/specimen/Lilita+One) (SIL Open Font License 1.1) and [Fira Code](https://github.com/tonsky/FiraCode) (SIL Open Font License 1.1).
