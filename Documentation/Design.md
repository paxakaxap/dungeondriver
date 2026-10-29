# Dungeon Driver Design

Dungeon Driver is an arcade racing RPG.

In the game, player race using cheap used cars from the 90’s, through the eastern-European back roads and abandoned factories.

Winning races, and completing side objectives during race grants player cash and car parts with  semi-randomized stats. Player can then install those parts into his chosen car, increasing it’s performance. 

### **Career**

Career is the main mode of the game. In it, player can join various races, and gain rewards. What type of race is available is decided by in-game calendar. Every day, three different races are presented to the player. Finishing a race ends the day, making the other two choices unavailable. 

Main goal of the game is to become a champion of three racing leagues. To become a champion, player must win three Sunday Cups, each corresponding to a league. Each Sunday cup consists of three consecutive races. Sunday Cups can be joined only on Sundays, according to the in-game calendar. Sunday cups races are more difficult that regular races. In it player’s rivals are equipped with better cars and make less mistakes. Winning the Sunday Cup, unlocks the next league, with more difficult daily races and higher tier Sunday Cup. Races in higher leagues grant better rewards.

### Race

Before picking a race, player is informed about: 

Venue - in game location with various track, for ex.The Mill, The Village, The Ruins

Track - which parts of said venue are the track

Type - circuit, sprint, time attack 

Competitors - up to 7

Terrain - for ex 80% asphalt 20% dirt

Time of day - Morning, Noon, Sunset, Night

Rewards - What is the prize for winning. Some races grant rewards for the first place, some for the podium, some for each opponent bested. 

For ex: Gold: “Unknown Rare Tires” + $1000, Sliver: “Unknown Common Tires” + $500, Bronze: $500

Races take place on varied terrain, from concrete to mud. Having proper tires increases the chances of winning. 

#### The Crate

In each race there is a crate placed somewhere on the track. Breaking it with your car grants an additional random item drop at the end of the race. Whoever broke the crate is marked during the race. Hitting the marked driver strong enough transfers the mark and the reward to the other driver.

### Upgrades and Inventory

One of the defining mechanics of Dungeon Driver is collecting car upgrades. Rather than just upgrading your car in a linear fashion, player earns car parts of various rarity through completing challenges and random drops. This mechanic is inspired by dungeon crawling RPGs like Diablo or Borderlands. 

Each earned car part lands in player’s inventory. Player can then equip those parts to his car in his garage, by clicking and dragging the item onto the corresponding slot on a car’s diagram. 

The part types are:

Engine - most expensive and the most important. Defines the car power characteristic.

Forced Injection - Turbo and superchargers, increase the power in various ways.

Transmission - upgrading it increases the gear change speed and lowers weight. (maybe unnecessary?)

Nitrous - various capacity, power, recharge rates, usage types

Tires - various types for various terrain

Suspension - height, stiffness, damping

Interior - weight reduction and weight distribution, chassis stiffness 

### Areas

In the career mode, player has access to various areas, accessible through menu:

Racing leagues - Here he can browse races available this day and start one.

Garage - here he can pick a car from his collection and upgrade it using collected parts.

Part Shop - her he can buy parts for cash or sell his unused parts. There are 3 parts for each type available each week.

Car Shop - here he can buy cars. 3 random cars are available each week.

### Flow

When starting the game player is presented with 3 empty save slots.

After picking the save slot, player is presented with main menu. In it, player can choose New Career (or Continue Career if its not his first time) or Quick Race.

Choosing New Career: Player starts an intro race with a predefined, decently upgraded car. After finishing the race, player is presented with three cars. He needs to pick one, which will become his car in the career. Then he is presented with the Career area screen. 

Quick race: Player can define race conditions and then pick a car from a group of a set of predefined ones, and start the race.

### Potential LAN multiplayer mode (likely out of scope)

every player drafts parts like in mtg draft. Then they spend limited money to buy 3 cars (or also draft them) and upgrade them using those parts. The cup consists of 3 races. Players need to assign 1 car to each race.

First two races grant additional parts.

whole match should last between 30min and an hour.