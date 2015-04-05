file_endings = Dict(
:jl => "julia", 
:glsl => "glsl", 
:frag => "glsl", 
:vert => "glsl", 
:cpp => "c++", 
:hpp => "c++",
:h => "c",
:h => "c",
:py => "python"
)
comments = Dict(
"julia" 	=> ["#", "#=", "=#"], 
"glsl" 		=> ["\\\\", "\\*", "*\\"], 

"c++" 		=> ["\\\\", "\\*", "*\\"], 
"c" 		=> ["\\\\", "\\*", "*\\"], 
"python" 	=> ["#", "\"\"\"", "\"\"\""]
)
import Base: read, write, (==), open 
immutable File{Ending}
	abspath::UTF8String
end
(==)(a::File, b::File) = a.abspath == b.abspath
ending{Ending}(::File{Ending}) = Ending
function File(file)
	@assert !isdir(file) "file string refers to a path, not a file. Path: $file"
	file 	= abspath(file)
	path 	= dirname(file)
	name 	= file[length(path):end]
	ending 	= rsearch(name, ".")
	ending  = isempty(ending) ? "" : name[first(ending)+1:end]
	File{symbol(ending)}(file)
end
macro file_str(path::AbstractString)
	File(path)
end
read{Ending}(f::File{Ending}; options...)  = error("no importer defined for file ending $T in path $(f.abspath), with options: $options")
write{Ending}(f::File{Ending}; options...) = error("no exporter defined for file ending $T in path $(f.abspath), with options: $options")
Base.open(x::File)       = open(abspath(x))
Base.abspath(x::File)    = x.abspath
Base.readbytes(x::File)  = readbytes(abspath(x))
Base.readall(x::File)    = readbytes(abspath(x))
const newlines = ["\n", "\r"]
function is_newline(current::AbstractString, s::IO)
	current == "\n" && return true
	if current == "\r"
		eof(s) && return true
		mark(s)
		str = string(read(s, Char)) 
		if str == "\n"
			unmark(s)
			return true
		end
		reset(s)
		return true
	end
	false
end

function is_comment(current::AbstractString, s::IO, delim)
	current == "\n" && return true
	if current == "\r"
		eof(s) && return true
		mark(s)
		str = string(read(s, Char)) 
		if str == "\n"
			unmark(s)
			return true
		end
		reset(s)
		return true
	end
	false
end

a = IOStream("\n")
b = IOStream("\r\n")
c = IOStream("asd")

@assert(is_newline("\n", a))
@assert(is_newline("\r", b))
@assert(!is_newline("a", c))

function count_nl{Ending}(f::File{Ending})
	!haskey(file_endings, Ending) && return 0
	multiline_comment 	= false
	multi_newline 		= false
	singleline_comment	= false

	language 			= file_endings[Ending]
	single_line, multiline_start, multiline_end = comments[language]
	count = 0
	s = open(f)
	tmp = Uint8[0]
	while !eof(s)
		str = string(read(s, Char)) 
		if multiline_comment
			println("ARRG")
			str == multiline_end && (multiline_comment = false)
			continue
		end
		if singleline_comment
			println("ARRG2")
			is_newline(str, s) && (singleline_comment = false)
			continue
		end
		if multi_newline
			println("ARRG23")
			!is_newline(str, s) && (multi_newline = false)
			continue
		end
		if multiline_start == str
			println("ARRG223")
			multiline_comment = true
			continue
		end
		if single_line == str
			println("ARRG222433")
			singleline_comment = true
			continue
		end
		is_newline(str, s) && (count += 1)
	end
	count
end
println(count_nl(file"count_files_lines.jl"))