using GLFW
GLFW.Init()
GLFW.WindowHint(GLFW.SAMPLES, 4)

window = GLFW.CreateWindow(512,512, "test")
GLFW.MakeContextCurrent(window)
GLFW.ShowWindow(window)

function droped_files(window::GLFW.Window, count::Cint, files::Ptr{Ptr{UInt8}})
	str_arr = pointer_to_array(files ,count, true)
	println(map(bytestring, str_arr))
	nothing
end
function unicode_mods(window::GLFW.Window, unic::Cuint, mod::Cint)
	println(Char(unic))
	println(mod)
	nothing
end

GLFW.SetDropCallback(window, droped_files)
GLFW.SetCharModsCallback(window, unicode_mods)



while !GLFW.WindowShouldClose(window)
	GLFW.PollEvents()
end
GLFW.Terminate()