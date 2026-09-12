Engine Third Party Dependencies
===============================


I would like to pack every needed source directly, so just cloning this repo
would pull everything. But doing it that way made inconvenient to contribute
fixes to upstream projects.

For now, we are using submodules for projects I contribute to from time to time. 

Over time we can change how we pack third party code.

Some dependencies have a script (like `odin.sh`). These do a checkout if not
found and run some compile commands. In the case where we want to stop using
submodules these could be updated to grab source code from upstream and apply
patches.


