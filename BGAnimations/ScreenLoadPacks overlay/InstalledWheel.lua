local create_base_wheel = LoadActor("./BaseWheel.lua")

return function(args)
	args.name = "InstalledWheel"
	args.side = "installed"
	args.title_key = "RightWheelTitle"
	return create_base_wheel(args)
end
