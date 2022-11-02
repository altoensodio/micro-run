-- micro-run - Press F5 to run the current file, F12 to run make, F9 to make in background
-- Copyright 2020-2022 Tero Karvinen http://TeroKarvinen.com/micro
-- https://github.com/terokarvinen/micro-run

local config = import("micro/config")
local shell = import("micro/shell")
local micro = import("micro")
local os = import("os")

function init()
	config.MakeCommand("runit", runitCommand, config.NoComplete)
	config.TryBindKey("F5", "command:runit", true)

	config.MakeCommand("makeup", makeupCommand, config.NoComplete)
	config.TryBindKey("F12", "command:makeup", true)

	config.MakeCommand("makeupbg", makeupbgCommand, config.NoComplete)
	config.TryBindKey("F9", "command:makeupbg", true)	
end

function runitCommand(bp) -- bp BufPane
		-- save & run the file we're editing
		-- choose run command according to filetype detected by micro
		bp:Save()

		local filename = bp.Buf.GetName(bp.Buf)
		local filetype = bp.Buf:FileType()
		local cmd = string.format("./%s", filename) -- does not support spaces in filename
		if filetype == "go" then
			if string.match(filename, "_test.go$") then
				cmd = "go test"
			else
				cmd = string.format("go run '%s'", filename)
			end
		elseif filetype == "python" then
			cmd = string.format("python3 '%s'", filename)
		elseif filetype == "html" then
			cmd = string.format("firefox-esr '%s'", filename)
		elseif filetype == "lua" then
			cmd = string.format("lua '%s'", filename)
		end

		shell.RunInteractiveShell(cmd, true, false)		
end

function makeup(bg)
	-- Go up directories until a Makefile is found and run 'make'. 
	
	-- Caller is responsible for returning to original working directory,
	-- and micro will save the current file into the directory where 
	-- we are in. In this plugin, makeupCommand() implements returning 
	-- to original directory

	micro.Log("bg: ", bg)

	local err, pwd, prevdir
	for i = 1,20 do -- arbitrary number to make sure we exit one day
		-- pwd
		pwd, err = os.Getwd()
		if err ~= nil then
			micro.InfoBar():Message("Error: os.Getwd() failed!")
			return
		end
		micro.InfoBar():Message("Working directory is ", pwd)

		-- are we at root
		if pwd == prevdir then
			micro.InfoBar():Message("Makefile not found, looked at ", i, " directories.")
			return
		end
		prevdir = pwd

		-- check for file
		local dummy, err = os.Stat("Makefile")
		if err ~= nil then
			micro.InfoBar():Message("(not found in ", pwd, ")")
		else
			micro.InfoBar():Message("Running make, found Makefile in ", pwd)
			if bg then
				local outfunc, err = shell.RunBackgroundShell("make")
				-- local out = string.sub(outfunc(), -60) -- this will block, can't edit when blocking
				-- micro.InfoBar():Message("'make' done: ", out)
			else
				local out, err = shell.RunInteractiveShell("make", true, true)
			end
			return
		end

		-- cd ..
		local err = os.Chdir("..")
		if err ~= nil then
			micro.InfoBar():Message("Error: os.Chdir() failed!")
			return
		end
		
	end
	micro.InfoBar():Message("Warning: ran full 20 rounds but did not recognize root directory")
	return

end	

function makeupWrapper(bg)
	-- makeupWrapper returns us to original working directory after running make
	-- this must be used, because ctrl-S saving saves the current file in working directory
	-- if bg is true, run 'make' in the background
	micro.InfoBar():Message("makeup called")

	-- pwd
	local pwd, err = os.Getwd()
	if err ~= nil then
		micro.InfoBar():Message("Error: os.Getwd() failed!")
		return
	end
	micro.InfoBar():Message("Working directory is ", pwd)
	local startDir = pwd

	makeup(bg)

	-- finally, back to the directory where we were
	local err = os.Chdir(startDir)
	if err ~= nil then
		micro.InfoBar():Message("Error: os.Chdir() failed!")
		return
	end
end

function makeupCommand(bp)
	-- run make in this or any higher directory, show output
	bp:Save()
	makeupWrapper(false)
end

function makeupbgCommand(bp)
	-- run make in this or higher directory, in the background, hide most output
	bp:Save()
	makeupWrapper(true)	
end
