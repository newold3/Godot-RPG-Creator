# Godot RPG Creator 🛠️

**An Open Source tool to create your own RPGs, built with Godot Engine.**

> ⚠️ **STATUS: ALPHA**
> This project is currently in an early development stage (Alpha). It is functional but may contain bugs, incomplete features, or mechanics subject to change. Use it at your own risk and remember to make backups!

Video on youtube: https://youtu.be/1eVzQd9EiM4

<img width="2515" height="1291" alt="image3" src="https://github.com/user-attachments/assets/c181dada-5216-44d5-a0d6-481c2d4e51a6" />


## 📖 Description

Godot RPG Creator is a suite of tools designed to facilitate the creation of 2D role-playing games, inspired by classics like RPG Maker but with the flexibility and power of Godot. My goal is to offer a free and open-source (MIT License) alternative for the community.

## ✨ Key Features (Current)

What you will find in this Alpha version:

### 🎨 Character Creator
* Simple visual editor.
* Selection of parts and custom coloring.
* Save and load character presets.

### 📚 Complete Database
* **Data Management:** Configuration of Skills, Items, Weapons, Armors, and Enemies with multiple parameters.
* **Battle System (WIP):** Definition of encounters, conditions, and formulas (logic implemented, visual battle in development).
* **Global Configuration:** Settings for vehicles, music, sounds, and a complete **Day/Night** system.

### 🗺️ Advanced Map Editor
* **Map Creation:** Create, edit, and manage multiple maps and scenes.
* **Layers & Terrain:** Terrain painting, ground details (e.g., grass), and environment layers.
* **Lighting & Shadows:** "Cast Shadow" property configurable per tile (with specific width and height).
* **Passability:** Collision configuration and directional passability settings.
* **Depth:** "Keep on Top" option for elements that must always appear above a tile.

### ⚡ Event System
* **Event Commands:** Extensive list of logic and visual commands.
* **Favorites & Search:** Filter commands by name (e.g., "Open") or add them to favorites for quick access.
* **Message Editing:** Integrated commands within text to display faces, names, or play sounds in a single line.
* **Extraction Events:** Base system for gathering/crafting mechanics (requires learned profession).
* **Region Events:** Area-based triggers for logic when entering/exiting zones.

### ⚙️ Other Tools
* **Visual Configuration:** WYSIWYG editor for positioning UI elements and images.
* **Quest System:** Database ready for missions (full implementation in progress).

---

## 🚀 Roadmap & Upcoming Features

Here is the development plan. I have reorganized the priorities to ensure a stable core before adding complex mechanics like combat.

### 🔥 Immediate Priority (Current Focus)
* **Steampunk UI Completion:** My main goal right now is to finish and polish all the menus in the Steampunk theme (Shops, Themed Dialogues, Item Menu, Skill Menu, and Status Menu).
* **Missing Event Commands:** Implementation of the remaining logic and event commands (excluding Battle-specific commands).

### 🚧 Upcoming Features (Mid-term)
* **Simplified UI Templates:** Development of a standard, simplified version of the menus. The current Steampunk theme uses complex animations and custom scripts; this alternative will be easier to edit and customize for users with less experience.
* **Event Systems:** Integration of the Event Quest System and a Relationship/Reputation system.
* **Vehicles:** Creation of the gameplay scene for the **Water Vehicle**.

### 🔮 Scheduled for Final Phase (Late Alpha)
* **Advanced Battle System:** The logic and visual implementation of the Battle System (Turn-Based/ATB) will be one of the last features to be added.
* **Final Content Polish:** The final configuration of the Database, Tilesets, and Animations will be addressed towards the end of development to ensure they match all implemented systems.

> *Ongoing tasks include continuous bug fixing, code refactoring, and polishing of existing scenes.*

---

## 🐛 Bug Reporting & Feedback

Your help is essential! As a solo developer (@Newold), I cannot test every possible combination.

### Found a bug?
Please open an **[Issue]** in this repository describing:
1.  What you were trying to do.
2.  What happened (error, crash, unexpected behavior).
3.  Steps to reproduce it (if known).

### Have a suggestion?
Do you think something essential is missing? Would you change how a tool works?
Open an **[Issue]** with the `enhancement` or `suggestion` label. I am open to discussing new implementations or changes to the current logic to make the tool better for everyone.

---

## 📥 Installation

1.  Clone this repository or download the ZIP.
2.  You need **Godot 4.x** installed.
3.  Import the project (`project.godot`) into the engine.
4.  Run and start creating!

---

## 📄 License

This project is distributed under the **MIT License**. You are free to use it, modify it, and distribute the games created with it, even commercially.

---
*Developed with ❤️ by Newold.*
