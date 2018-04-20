#!/usr/bin/env sh
LUA_PATH="../?.lua;../shared/?.lua;../react/?.lua;../reconciler/?.lua;$LUA_PATH" luajit $1-test.lua
