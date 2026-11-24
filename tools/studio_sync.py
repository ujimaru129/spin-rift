#!/usr/bin/env python3
"""Prints a one-line command for Studio's command bar that puts the scripts changed since a commit
into the open place, checking first that Studio still holds that commit's version:

    python3 tools/studio_sync.py BASE_COMMIT | LC_ALL=en_US.UTF-8 pbcopy

BASE_COMMIT is the commit that was last put into Studio. Output ends with "OK n of n PLACE_ID"."""
import os, subprocess, sys

ROOTS = {"src/shared": "game.ReplicatedStorage.Shared", "src/server": "game.ServerScriptService.Server", "src/client": "game.StarterPlayer.StarterPlayerScripts.Client"}


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, check=True).stdout


def lua(b):
    return b.decode().replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def total(b):
    return sum(b) % 1000003


base = sys.argv[1]
out, n = ["local SE=game:GetService(\"ScriptEditorService\") local good=0 local function sum(s) local x=0 for i=1,#s do x=(x+s:byte(i))%1000003 end return x end if game.PlaceId~=110287689388097 then error(\"wrong place\") end "], 0
for line in git("diff", "--name-status", base, "--", "src").decode().splitlines():
    status, f = line.split("\t")
    root = next(r for r in ROOTS if f.startswith(r + "/"))
    parts = f[len(root) + 1 :].split("/")
    name = parts.pop().split(".")[0]
    parent = ".".join([ROOTS[root], *parts])
    assert status in "AM", line
    n += 1
    new = open(f, "rb").read()
    if name == "init":
        get = f"local m={parent} "
    else:
        get = f'local p={parent} local m=p:FindFirstChild("{name}") '
        if status == "A":
            get += f'if not m then m=Instance.new("ModuleScript") m.Name="{name}" m.Parent=p end '
    guard = "true"
    if status == "M":
        old = git("show", f"{base}:{f}")
        guard = f"(#m.Source=={len(old)} and sum(m.Source)=={total(old)})"
    out.append(f'do {get}if {guard} or sum(m.Source)=={total(new)} then SE:UpdateSourceAsync(m,function() return "{lua(new)}" end) end '
               f'if #m.Source=={len(new)} and sum(m.Source)=={total(new)} then good+=1 else warn("BAD {f}",#m.Source) end end ')
out.append(f'print("OK",good,"of {n}",game.PlaceId)')
print("".join(out), end="")
