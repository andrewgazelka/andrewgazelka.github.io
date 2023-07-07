---
layout: post
title: "SwarmBot Issues"
---

A few years ago I created [SwarmBot](https://github.com/SwarmBotMC/SwarmBot), an autonomous bot launcher for Minecraft in Rust. I called it *Swarm*bot because it is capable of launching hundreds of bots, each one on a separate SOCKS5 Socket, which is nice for servers like `2b2t`, where I launched about 200 of them at once (this is ethical and within the server rules).

One of the main components of *SwarmBot* is its ability to parkour as seen in the video below

<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/IbL96hVcCZc?controls=0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

It might seem like the bot posseses a superpower being able to do relatively complex jumps with ease, but it is really just a block-level A* and then a really well find-tuned algorithm that takes a list of blocks and figures out which actions (run, look, jump, etc) it should perform based on the direction and distance of the next block the bot needs to reach.

This works well 99% of the time, but it isn't a guarentee the bot will work, and there are some cases the bot will not really be able to succeed without A LOT of spaghetti code—say for complex jumps like neos.

![neo jump](assets/neo.png)

Neo jumps are especially complex because it doesn't involve looking towards the next block in the sequence of blocks that need to be jumped to. Instead, it involves jumping *around* a block (facing away from the block to be jumped to) before finally looking at the block.

I had to implement physics on the client side to get the bot to behave like a normal player and to be able to be used on servers with NoCheatPlus. Therefore, I figured why not use physics to instead of discretize based on block to instead of discretize based on gametick and have children nodes be based on keys the player could press.

Below is the same parkour course as in the video above. Each green circle is a block and each node explored is black. No heuristic is used (unlike in the video) and the following options are
- **run forward** (cost 1)
- **run forward and jump** (cost 1)
- **run forward and turn left 15º** (cost 10)
- **run forward and turn right 15º** (cost 10)

![a-star](assets/a-star.png)

As you can see there is a big issue. When the bot looks at possible turns, lower `g-scores` are taken into account first when really the ones that need to be tried are those furthest along (highest g-scores). My guess it would take until the end of the universe for this problem to finish. Potentially there is some great heuristic I can use, but I can't think of one.

