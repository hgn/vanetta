#!/usr/bin/env ruby 

# == Synopsis 
#   This programm parse ns3 trace files formatted
#   with the new trace file format introduced by
#   monarch extension
#
# == Examples
#   This command print out some simple statistics
#   vanetta.rb foo.tr
#
# == Usage 
#   vanetta.rb [options] <trace-files>
#
#   For help use: vanetta.rb -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -q, --quiet         Output as little as possible, overrides verbose
#   -f, --format        Specify the output format (png, pdf, svg and ps)
#   -V, --verbose       Verbose output
#
# == Author
#   Patrick Rehm
#   Hagen Paul Pfeifer <hagenjauu.net>
#
# == Copyright
#   Copyright (c) 2008 Patrick Rehm, Hagen Paul Pfeifer



require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
require 'date'

moving_node = 10

DEFAULT_OUTPUT_PATH = "images/"
W = 2000
H = 2000


@options
@trace_file

class Contexter

	attr_reader :format, :surface, :cr, :path

	def initialize(format, path)
		@path    = path
		@format  = format
		init_context()
	end

	def init_context()

		case @format
		when "png"
			@surface = Cairo::ImageSurface.new(W, H)
			@cr      = Cairo::Context.new(surface)
		when "pdf"
			@surface = Cairo::PDFSurface.new(@path + ".pdf", W, H)
			@cr      = Cairo::Context.new(surface)
		else
			$stderr.print("Format not supported: #{@format}, exiting")
			exit
		end

	end

	def reinit( path )
		self.fini
		self.init_context( @format, path)
	end

	def fini
		case format
		when "png"
			@cr.show_page
			@surface.write_to_png(path + ".png")
		else
			@cr.show_page
			@cr.finish
		end
	end
end

def draw_topology( streams, width, height, path )

	x_max = Integer::MIN; y_max = Integer::MIN;
	x_min = Integer::MAX; y_min = Integer::MAX;
	x_scaling = 0; y_scaling = 0;

	colors = [
		Cairo::Color::RGB.new(0.0, 0.0, 1),
		Cairo::Color::RGB.new(0.3, 0.9, 0.7),
		Cairo::Color::RGB.new(0.1, 0.2, 0.6),
		Cairo::Color::RGB.new(0.9, 0.8, 0.4),
		Cairo::Color::RGB.new(0.3, 0.3, 0.2),
		Cairo::Color::RGB.new(0.6, 0.6, 0.1),
		Cairo::Color::RGB.new(0.1, 0.9, 0.2),
		Cairo::Color::RGB.new(0.5, 0.1, 0.5),
		Cairo::Color::RGB.new(0.8, 0.9, 0.7),
		Cairo::Color::RGB.new(0.3, 0.3, 0.3),
	]

	black = Cairo::Color::RGB.new(0.0, 0.0, 0.0)

	coordinates = Hash.new

	# first iterate over all x and y values and
	# determine minimum and maximum of it. This
	# step is required to determine the scaling factor
	streams.each do |time, value|
		value.each do |nodes, value|
			if x_max <= value["coordinates"][0].to_i
				x_max =  value["coordinates"][0].to_i
			end
			if y_max <= value["coordinates"][1].to_i
				y_max =  value["coordinates"][1].to_i
			end
			if x_min >= value["coordinates"][0].to_i
				x_min =  value["coordinates"][0].to_i
			end
			if y_min >= value["coordinates"][1].to_i
				y_min =  value["coordinates"][1].to_i
			end
		end
	end

	if @options.verbose
		$stderr.print "offset x: #{x_min} y: #{y_min}\n"
		$stderr.print "scaling x: #{x_max - x_min} y: #{y_max - y_min}\n"
	end

	x_scaling = width.to_f / (x_max - x_min)
	y_scaling = height.to_f / (y_max - y_min)

	x_offset = x_min
	y_offset = y_min

	streams.sort.each do |time, nodes|

		context = Contexter.new(@options.format, @options.output_path + @options.topology + "#{time}")

		# draw canvas
		context.cr.set_source_color(:white)
		context.cr.rectangle(0, 0, width, height).fill

		nodes.sort.each do |node, node_data|

			x = (node_data["coordinates"][0] - x_offset).to_f * x_scaling
			y = (node_data["coordinates"][1] - y_offset).to_f * y_scaling

			# display node
			node_color = colors[node.to_i % colors.size]
			node_color.alpha = 0.5
			context.cr.set_source_color(node_color)
			context.cr.set_line_width(1.0)
			context.cr.arc(x, y, 100.0, 0, 2 * Math::PI);
			context.cr.fill

			# dislay node index
			context.cr.set_source_color(black)
			context.cr.move_to(x, y)
			context.cr.show_text( " #{sprintf("Node %d", node.to_i)}" )
			context.cr.stroke

			# display neighboor links
			node_data["neighbors"].each do |neighbor|
				my_x = (node_data["coordinates"][0] - x_offset).to_f * x_scaling
				my_y = (node_data["coordinates"][1] - y_offset).to_f * y_scaling
				foreign_x = (nodes[neighbor.to_i]["coordinates"][0] - x_offset).to_f * x_scaling
				foreign_y = (nodes[neighbor.to_i]["coordinates"][1] - y_offset).to_f * y_scaling

				context.cr.set_source_color(:red)
				context.cr.move_to(my_x, my_y)
				context.cr.line_to(foreign_x, foreign_y)
				context.cr.stroke
			end


		end

		context.fini
	end



end

def create_topology( streams, path )

	require 'cairo'

	width = 2000
	height = 2000

	@options.topology = "scenario"

	draw_topology(streams, width, height, path)


end

def split_trace_into_streams( file )
	hash = Hash.new
	fd = File.open(file)
	fd.readlines.each do |line|
		line.chomp!
		if line =~ /(\d+.\d+)\W+(\d+)\W+(\d+)\W+(\d+)\W+(.*)/
			time       = $1.to_f
			node_index = $2.to_i
			if hash[time] == nil
				hash[time] = Hash.new
			end
			if hash[time][node_index] == nil
				hash[time][node_index] = Hash.new
			end
			hash[time][node_index]["coordinates"] = [ $3.to_i, $4.to_i, $5.to_i ]

			# Write the neighbors into the hash
			hash[time][node_index]["neighbors"] = $5.split(' ')
		end
	end
	return hash
end


def open_output_dir( path )

	tmp_path = File.expand_path(path)
	if File.exists?(tmp_path) && File.directory?(tmp_path)
		$stderr.puts("Output directory \"#{tmp_path}\" exist already - overwrite content!")
		return
	end

	Dir.mkdir(tmp_path)
end


def init( arguments, stdin )
	@arguments = arguments
	@stdin = stdin

	# Set defaults
	@options = OpenStruct.new
	@options.verbose = false
	@options.quiet = false
	@options.format = "png"
	@options.output_path = DEFAULT_OUTPUT_PATH
end

# Parse options, check arguments, then process the command
def run

	if parsed_options? && arguments_valid? 

		process_arguments            
		process_command

	else
		output_usage
	end

end

def parsed_options?

	# Specify options
	opts = OptionParser.new 
	opts.on('-V',        '--version')    { output_version ; exit 0 }
	opts.on('-h',        '--help')       { output_help }
	opts.on('-v',        '--verbose')    { @options.verbose = true }  
	opts.on('-q',        '--quiet')      { @options.quiet = true }
	opts.on('-f [format]', '--format')   { |format| @options.format = format}
	opts.on('-d [dir]',    '--directory'){ |path| @options.output_path = path}

	opts.parse!(@arguments) rescue return false

	process_options
	true      
end

def process_options
	@options.verbose = false if @options.quiet
end

def arguments_valid?
	true if @arguments.length == 1 
end

# Setup the arguments
def process_arguments
	@trace_file = @arguments[0]
end

def output_help
	output_version
	RDoc::usage()
end

def output_usage
	RDoc::usage('usage')
end

def output_version
	$stderr.puts "#{File.basename(__FILE__)} version"
end

def process_command
	$stderr.puts "trace file: #{@trace_file}" if @options.verbose

	streams = split_trace_into_streams( @trace_file )
	puts "streams detected #{streams.length}" if @options.verbose
	if @options.verbose
		puts "topology creation (imagename: #{@options.topology})"
	end

	open_output_dir(@options.output_path)

	create_topology( streams, @options.output_path )

end

# define Integer::MAX, Integer::MIN
class Integer
	N_BYTES = [42].pack('i').size
	N_BITS = N_BYTES * 8
	MAX = 2 ** (N_BITS - 2) - 1
	MIN = -MAX - 1
end


init(ARGV, STDIN)
run
