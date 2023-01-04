---
layout: page
title: Concurrent Rust Deep Dive
date: 2023-01-01 04:20:44 -0700
categories: rust concurrency
has_children: true
has_toc: true
---

# Concurrent Rust Deep Dive

{:.warning}
This article is currently a WIP. Certain pages are not finished and often contain many TODOs.

{:.warning}
I have played around with OpenAI [edit](https://beta.openai.com/docs/guides/completion/editing-text) and [insert](https://beta.openai.com/docs/guides/completion/inserting-text) 
APIs for small but significant portions of the article. I have edited and reviewed the information, but it is totally possible I have missed a few things which are not entirely correct.

{:.todo}
👀 [optimizing-await-1](https://tmandry.gitlab.io/blog/posts/optimizing-await-1/)

{:.todo}
👀  [optimizing-await-2](https://tmandry.gitlab.io/blog/posts/optimizing-await-2/)

{:.todo}
👀  [may](https://github.com/Xudong-Huang/may)

{:.todo}
👀  [xitca-web](https://github.com/HFQR/xitca-web)

{:.todo}
👀  [tock](https://www.tockos.org/)

{:.todo}
👀  RTOS

{:.todo}
https://www.drone-os.com/


Happy New Year everyone! Welcome to 2023. I do a lot of work using asynchronous programming. I thought it would
be useful to write a post to clear it up for those less familiar with the concept. I think this is specifically
useful because there are quite a few misconceptions and roadblocks that beginners to the topic usually run into.
