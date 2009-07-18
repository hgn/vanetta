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


@options
@trace_file


def draw_topology( surface, streams, width, height )

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

  cr = Cairo::Context.new(surface)
  cr.set_source_color(:white)
  cr.rectangle(0, 0, width, height).fill
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

  # and draw the streams
  current_x = -1
  current_y = -1
  cr.set_line_width(1.0)


  streams.sort.each do |time, nodes|
	  nodes.sort.each do |node, node_data|

		  x = node_data["coordinates"][0] - x_offset
		  y = node_data["coordinates"][1] - y_offset

		  node_color = colors[node.to_i % colors.size]
		  node_color.alpha = 0.5
		  cr.set_source_color(node_color)
		  cr.set_line_width(1.0)
		  puts "x #{x.to_f * x_scaling} y #{y.to_f * y_scaling}"
		  cr.arc(x.to_f * x_scaling, y.to_f * y_scaling, 100.0, 0, 2 * Math::PI);
		  cr.fill
	  end
  end

  return cr.show_page

  exit

  streams.sort.each do |key, value|
    draw_already_once = 0

    # rand() ONE value of the whole dataset
    # if we match this later in the loop we
    # print the node ID. This is a workaround
    # to display the IDs per node when they
    # are somewhere on the map.
    datasetmatch = value[rand(value.size)]

    matcharray = Array.new
    # and n values for timestamping
    diff = value.size / 5
    current_diff = rand(5)
    5.times do
      matcharray << value[current_diff % value.size]
      current_diff += diff
    end

    value.each do |dataset|


      if current_x == -1 and current_y == -1
        current_x = dataset[1].to_f
        current_y = dataset[2].to_f
        next
      end

      node_color = colors[key.to_i % colors.size]

      # draw static nodes first
      if key.to_i != 10

      # draw lines
      node_color.alpha = 0.3
      cr.set_line_width(1.0)
      cr.set_source_color(node_color)
      cr.move_to(current_x * x_scaling, current_y * y_scaling)
      cr.line_to(dataset[1].to_f * x_scaling, dataset[2].to_f * y_scaling)
      cr.stroke

      # draw waypoints
      if draw_already_once != 1

        node_color = colors[key.to_i % colors.size]
        node_color.alpha = 0.03
        cr.set_source_color(node_color)
        cr.set_line_width(1.0)
        cr.arc(current_x.to_f  * x_scaling, current_y.to_f * y_scaling, 150.0 * x_scaling, 0, 2 * Math::PI);
        cr.fill
        draw_already_once = 1

        node_color = colors[key.to_i % colors.size]
        node_color.alpha = 1
        cr.set_source_color(node_color)
        cr.set_line_width(1.0)
        cr.arc(current_x.to_f  * x_scaling, current_y.to_f * y_scaling, 150.0 * x_scaling, 0, 2 * Math::PI);
        cr.stroke
        draw_already_once = 1

      end


      else # dynamic nodes

        # draw lines
        node_color.alpha = 0.3
        cr.set_line_width(1.0)
        cr.set_source_color(node_color)
        cr.move_to(current_x * x_scaling, current_y * y_scaling)
        cr.line_to(dataset[1].to_f * x_scaling, dataset[2].to_f * y_scaling)
        cr.stroke

        # display time information for node 10
        matcharray.each do |matchentry|
          if dataset == matchentry and dataset != datasetmatch
            node_color = colors[key.to_i % colors.size]
            node_color.alpha = 0.5
            cr.set_source_color(node_color)
            cr.move_to(current_x.to_f * x_scaling, current_y.to_f * y_scaling)
            cr.show_text( " #{sprintf("%.2f", dataset[0])}s" )
            cr.stroke
          end
        end
      end

      # display node names
      cr.set_font_size(7)
      if dataset == datasetmatch
        cr.set_source_color(:black)
        cr.move_to(current_x.to_f * x_scaling, current_y.to_f * y_scaling)
        cr.show_text( " Node #{key}" )
        cr.stroke
      end


      current_x = dataset[1].to_f
      current_y = dataset[2].to_f
    end
    current_x = -1
    current_y = -1
  end

  return cr.show_page

end

def create_topology( streams )

  require 'cairo'

  width = 2000
  height = 2000

  @options.topology = "scenario"

  case @options.format
  when "png"
    @options.topology += ".png"
    sf = Cairo::ImageSurface.new(width, height)
    cr = draw_topology(sf, streams, width, height)
    cr.target.write_to_png(@options.topology)
  when "svg"
    @options.topology += ".svg"
    sc = Cairo.const_get("SVGSurface")
    surface = sc.new(@options.topology,  width, height) 
    draw_topology(surface, streams, width, height)
  when "pdf"
    @options.topology += ".pdf"
    sc = Cairo.const_get("PDFSurface")
    surface = sc.new(@options.topology,  width, height) 
    draw_topology(surface, streams, width, height)
  when "ps"
    @options.topology += ".ps"
    sc = Cairo.const_get("PSSurface")
    surface = sc.new(@options.topology,  width, height) 
    draw_topology(surface, streams, width, height)
  else
    @options.topology += ".png"
    sf = Cairo::ImageSurface.new(width, height)
    cr = draw_topology(sf, streams, width, height)
    cr.target.write_to_png(@options.topology)
  end

end

def split_trace_into_streams( file )
  hash = Hash.new
  fd = File.open(file)
  fd.readlines.each do |line|
    line.chomp!
    if line =~ /(\d+.\d+)\W+(\d+)\W+(\d+)\W+(\d+)\W+(\d+)/
      time       = $1.to_f
      node_index = $2.to_i
      if hash[time] == nil
        hash[time] = Hash.new
      end
      if hash[time][node_index] == nil
        hash[time][node_index] = Hash.new
      end
      hash[time][node_index]["coordinates"] = [ $3.to_i, $4.to_i, $5.to_i ]

      #Write the neighbors into the hash
      hash[time][node_index]["neighbors"] = Array.new
      temp = Array.new 
      temp = line.split(' ')

      #The 4 is kind of a magic number here, 
      #the fifth entry in the array is the number of neighbors
      no_neighbors = temp[4]
      for i in 0...no_neighbors.to_i
        hash[time][node_index]["neighbors"] << temp[5+i]
      end
    end
  end
  return hash
end


def init( arguments, stdin )
  @arguments = arguments
  @stdin = stdin

  # Set defaults
  @options = OpenStruct.new
  @options.verbose = false
  @options.quiet = false
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
  create_topology( streams )

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
