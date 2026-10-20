# 🌌 Stellar Exploration - Roadmap

This roadmap outlines the core goals and milestones for the upcoming versions of Stellar Exploration.

---

## 🛠️ Next Milestone: Version 0.3.0

### 🧠 Advanced AI & Learning System (Core Feature)
* **Faction-Based Learning:** Implement the local SQLite knowledge-base for AI factions to adapt to player tactics.
* **Strategic Utility AI:** Program the Lua-based decision matrix for AI factions (Attacking, Waiting, Fleeing via Warp).
* **Modular Recon Stations:** Enable AI to physisch build and stack sensor modules to spy on and analyze player behaviors.

### 🚀 Physics & Orbit Fixes
* **First-Person Orbit Lock:** ✅ The ship follows its orbit carrier's full transform, including rotation, during bridge view and across world rebases.
* **Orbit Mining Refinement:** ✅ Manual extraction is limited to a nearby planet the ship is currently orbit-locked to; switching targets persists the previous planet's resources.

### 🏭 Economy & Logistics Foundation
* **Physisch Rohstoff-Kette:** Implement local SQLite inventories for individual stations and freighters.
* **Isotope Hierarchy:** Add harvesting logic for Hydrogen (¹H), Deuterium (²H), and rare Tritium (³H) within stellar nebulae.
* **Refinery Stations:** Create the framework for refining raw minerals into construction alloys (e.g., Durasteel).

---

## 🛰️ Future Milestones (Version 0.4.0+)
* **Solar Antimatter Collection:** Stations orbiting close to stars utilizing high energy to harvest Antimatter.
* **In-Game Mod Catalog:** Safe Lua-only addon repository fetched dynamically via GitHub API.
* **Direct-IP Multiplayer:** Serverless cooperative gameplay via direct connection.
* **Land and Build on Planets:** You can enter any planet and explore it and build stations on that planet.