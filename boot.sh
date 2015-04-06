#!/bin/bash

export PATH="$HOME/.plenv/bin:$PATH"
eval "$(plenv init -)"
exec plenv exec carton exec perl wipi.pl
