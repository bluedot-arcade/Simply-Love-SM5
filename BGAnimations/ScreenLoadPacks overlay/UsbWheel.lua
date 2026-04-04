local create_base_wheel = LoadActor("./BaseWheel.lua")

return function(args)
	args.name = "UsbWheel"
	args.side = "usb"
	args.title_key = "LeftWheelTitle"
	return create_base_wheel(args)
end
