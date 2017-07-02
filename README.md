# CS2D-NEAT-Bots
Some weeks ago I stumbled upon a youtube video by SethBling where a computer program "learns" how to play a level in Super Mario World. In this video he explains how he uses a process called neuroevolution to make the program finish the level. 

So I started asking myself if I could write a program that "learns" how to play cs2d. 

I took the code from SethBling and rewrote it so I could use it on cs2d bots. He was using NEAT (neuroevolution of augmenting topologies).

Before I continue, I recommend you to watch his video, where he also explains how it works:
https://www.youtube.com/watch?v=qv6UVOQ0F44

# How it works:
NEAT basically generates a fixed number of neural networks. 

Neural networks are working similar to our brain. They get Inputs (information) and calculate Outputs (e.g. cs2d controls) based on the structure of the neural network.

All those generated neural networks get tested and rated with a fitness value based on how good they did on the given task (e.g killing enemies). When all neural networks have been tested the best with the highest fitness value get selected and a new generation of mutated neural networks gets generated. This new generation gets tested again -> best get selected -> new generation and so on...

Each generation the neural networks (should) get better.

# Implementation:
When I finished rewriting the code I realized that it would be highly unrealistic to make bots fully controlled by neural nets. 
Especially pathfinding is far to complex. So I decided to start with the enemy engage section of the bot code (when the bot has to fight an enemy).

Currently the neural network has the following inputs:
1 - Can I hit an enemy? Freeline and Angle (0 to 1 | no to yes)
2 - Nearest target angle (-1 to 1 | left to right)
3 - Target Distance (0 to 1 | near to far)
4 - Angle the enemy is aiming at relative me (-1 to 1 | left to right) 

The neural network can give the following outputs:
1 - Intelligent Attack! (if output > 0.5)
2 - Rotate (-1 to 1 | left to right)
3 - Change aim distance (0 to 1 | near to far)
4 - move X relative to target. (-1 to 1 | left to right) 
5 - move Y relative to target. (-1 to 1 | go away to get closer)

fitness evaluation:
Every time a bot takes longer than 200 frames to engage(timeout) or the bot respawns (bot has most likely died) the neural network gets evaluated and the next neural network gets tested.

fitness value is calculated with:
1 - Number of times the bot fires the right direction.
2 - Number of Scores / Kills
3 - Engagement time
4 - How close the bot was on aiming in the right direction

Here a video of a training process:
https://youtu.be/dk3VvSt6DXs 

I also implemented a save an load functionality so that you don’t have to restart training every time the server gets restarted. It creates a save file after each generation. 

# What has Changed?
- Added neat.lua in includes. This is an easy to use NEAT library.
- Changed Standard AI.lua. Imported neat.lua, created an NEAT object and called 
- Changed engage.lua completely. Prepares Inputs, calls evaluate to get outputs, performs output actions and rates each network with a fitness value

# Try it out.
Download the files and save them into your cs2d bot folder. 

There is already a save file called savefile.sf with trained bots. If you want them to start learning to fight from scratch, simply delete this file.

# How to use neat.lua?
With neat.lua you can run as many neuroevolution parallel as you want. All data gets stored in one object.


```lua
--load neat.lua
dofile("bots/includes/neat.lua")

--initialize a neuroevolution
myNeat = fai_neat_init(4,5) -- neural nets will have 4 inputs and 5 outputs

--optionally load saved evolution progress
fai_neat_load(myNeat, "bots/savefile.sf")

--prepare inputs
local inputs = {}
inputs[1] = lineOnTarget
inputs[2] = nearTargetDirection
inputs[3] = targetDistance
inputs[4] = enemyOffAngle

--evaluate a network to get outputs
local outputs = {}
outputs = fai_neat_evaluate(myNeat, 1, inputs) -- if you want to evaluate multiple neural nets at the same time, give each evaluation a unique number instead of 1

--if evaluation is finished -> rate neural net
local fitness = 100
fai_neat_rate(myNeat, 1, fitness) --calculate a fitness based on how well the neural net has done
-- neat rate automatically selects the next neural net after the old one has been rated
```
