#!/usr/bin/env sh
LUA_PATH="../?.lua;../react/?.lua;../reconciler/?.lua" luajit $1-test.lua
