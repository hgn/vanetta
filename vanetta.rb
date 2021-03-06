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
require 'ostruct'
require 'date'

DEFAULT_OUTPUT_PATH = "images/"
RTABLE_X_OFF = 100
RTABLE_Y_OFF = 0
LINE_Y_OFF = 20
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
        end
    end
end

class Theme
    attr_accessor :canvas_bg_color, :canvas_margin
    attr_accessor :node_arc_radius, :node_arc_outline_color, :node_arc_fill_color
    attr_accessor :node_index_color, :node_index_font_size , :node_index_offset
    attr_accessor :direct_neighbor_color, :direct_neighbor_alpha, :direct_neighbor_line_width
    attr_accessor :neighbor_table_bg, :neighbor_table_alpha, :neighbor_table_color
end


def draw_plain_node(cr, x, y, theme)

    cr.set_source_color(theme.node_arc_fill_color)
    cr.set_line_width(1.0)
    cr.arc(x, y, theme.node_arc_radius, 0, 2 * Math::PI);
    cr.fill

    cr.set_source_color(theme.node_arc_outline_color)
    cr.set_line_width(2.0)
    cr.arc(x, y, theme.node_arc_radius, 0, 2 * Math::PI);
    cr.stroke

    pr_verbose("draw node at x: #{x} y:#{y}")
end


def draw_image_node(cr, x, y, image )
    image = Cairo::ImageSurface.from_png(image)
    car_x  = x - (image.width.to_f / 2)
    car_y  = y - (image.height.to_f / 2)
    cr.set_source(image, car_x, car_y)
    cr.paint
    pr_verbose("draw vehicle at x: #{x} y:#{y}")
end


def draw_node(cr, x, y, theme)
    if @options.node_image
        draw_image_node(cr, x, y, @options.node_image)
    else
        draw_plain_node( cr, x, y, theme)
    end
end


def draw_canvas( cr, width, height, theme )
    if true
        cr.set_source_color(theme.canvas_bg_color)
        cr.rectangle(0, 0, width, height).fill
    else
        image = Cairo::ImageSurface.from_png("data/grass.png")
        pattern = Cairo::SurfacePattern.new(image)
        pattern.extend = Cairo::EXTEND_REPEAT

        matrix = Cairo::Matrix.new(1, 0, 0, -1, 50, 50)
        pattern.set_matrix(matrix)

        cr.set_source(pattern)
    end

    cr.rectangle(0, 0, width, height)
    cr.fill
    cr.paint
end

def calculate_offset_and_scaling(streams, width, height, theme)

    x_max = Integer::MIN; y_max = Integer::MIN;
    x_min = Integer::MAX; y_min = Integer::MAX;
    x_offset = y_offset = x_scaling = y_scaling = 0.0

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

    pr_verbose("offset x: #{x_min} y: #{y_min}")
    pr_verbose("scaling x: #{x_max - x_min} y: #{y_max - y_min}")

    offset = theme.node_arc_radius.to_f * 2 + theme.canvas_margin.to_f * 2

    if x_max != x_min
        x_scaling = (height.to_f - offset) / (x_max - x_min)
    else
        x_scaling = (height.to_f - offset) / (x_max)
    end

    if y_max != y_min
        y_scaling = (height.to_f - offset) / (y_max - y_min)
    else
        y_scaling = (height.to_f - offset) / (y_max)
    end

    x_offset = x_min
    y_offset = y_min

    return [x_offset, y_offset, x_scaling, y_scaling]
end

def draw_topology( streams, width, height, path, theme )

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

    x_offset, y_offset, x_scaling, y_scaling =
        calculate_offset_and_scaling(streams, width, height, theme)

    last_time = streams.sort[-1][0]

    streams.sort.each do |time, nodes|

        Tool.pr_swirl("draw map for time #{time}/#{last_time}")

        context = Contexter.new(@options.format,
                                @options.output_path + @options.topology + "#{sprintf("%03d", time)}")

        draw_canvas(context.cr, width, height, theme)

        # we assume the object is a square (if not: case differentiation for x and y)
        node_offset = theme.node_arc_radius + theme.canvas_margin

        nodes.sort.each do |node, node_data|

            x = (node_data["coordinates"][0] - x_offset).to_f * x_scaling + node_offset
            y = (node_data["coordinates"][1] - y_offset).to_f * y_scaling + node_offset

            # display node
            draw_node(context.cr, x, y, theme)

            pr_verbose("Nodes y: #{node_data["coordinates"][1]}")
            pr_verbose("y - Offset: #{node_data["coordinates"][1]} - #{y_offset}")
            pr_verbose("y - scaling: #{y_scaling}")
            pr_verbose("Calculated y: #{y}")

            # dislay node index
            context.cr.set_source_color(theme.node_index_color)
            context.cr.move_to(x + theme.node_index_offset, y + theme.node_index_offset)
            context.cr.set_font_size(theme.node_index_font_size)
            context.cr.show_text(" #{sprintf("Node %d", node.to_i)}")
            context.cr.stroke

            # display neighbor links
            node_data["neighbors"].each do |neighbor|
                my_x = (node_data["coordinates"][0] - x_offset).to_f * x_scaling + node_offset
                my_y = (node_data["coordinates"][1] - y_offset).to_f * y_scaling + node_offset
                foreign_x = (nodes[neighbor.to_i]["coordinates"][0] - x_offset).to_f * x_scaling + node_offset
                foreign_y = (nodes[neighbor.to_i]["coordinates"][1] - y_offset).to_f * y_scaling + node_offset

                color = theme.direct_neighbor_color
                color.alpha = theme.direct_neighbor_alpha
                context.cr.set_source_color(color)
                context.cr.set_line_width(theme.direct_neighbor_line_width)
                context.cr.move_to(my_x, my_y)
                context.cr.line_to(foreign_x, foreign_y)
                context.cr.stroke
            end

            #display node routing table
            my_x = (node_data["coordinates"][0] - x_offset).to_f * x_scaling + node_offset
            my_y = (node_data["coordinates"][1] - y_offset).to_f * y_scaling + node_offset
            draw_rtable(context.cr, my_x, my_y + 20, node, node_data, theme)

        end
        context.cr.stroke
        context.fini
    end
end

def roundedrec(cr, x, y, w, h, r = 15)
    cr.move_to(x+r,y)                      # Move to A
    cr.line_to(x+w-r,y)                    # Straight line to B
    cr.curve_to(x+w,y,x+w,y,x+w,y+r)       # Curve to C, Control points are both at Q
    cr.line_to(x+w,y+h-r)                  # Move to D
    cr.curve_to(x+w,y+h,x+w,y+h,x+w-r,y+h) # Curve to E
    cr.line_to(x+r,y+h)                    # Line to F
    cr.curve_to(x,y+h,x,y+h,x,y+h-r)       # Curve to G
    cr.line_to(x,y+r)                      # Line to H
    cr.curve_to(x,y,x,y,x+r,y)             # Curve to A
end


def draw_rtable(cr, x, y, node, node_data, theme)
    current_y = y
    current_x = x + RTABLE_X_OFF

    cr.set_font_size(17)

    #Draw the box around the Routing Table
    cr.move_to(current_x, y)
    cr.set_source_color(:gray)

    #Fill the routing table
    routing_table = Hash.new

    node_data["reachable"].each do |reachable|
        rt_data = reachable.split('-')
        routing_table[rt_data[0]] = rt_data[1]
    end

    node_data["neighbors"].each do |neighbor|
        routing_table[neighbor] = neighbor
    end

    #2 times LINE_Y_OFF for the heading, the bare 10 as offset
    box_size = routing_table.size * LINE_Y_OFF + 2 * LINE_Y_OFF + 10
    #cr.rectangle(current_x , y, 120, box_size).fill
    table_bg = theme.neighbor_table_bg
    table_bg.alpha = theme.neighbor_table_alpha
    cr.set_source_color(table_bg)
    roundedrec(cr, current_x , y, 200, box_size)
    cr.fill

    #Draw the actual Routing Table
    current_y += LINE_Y_OFF
    cr.set_source_color(theme.neighbor_table_color)
    cr.move_to(current_x, current_y)
    cr.show_text(" #{sprintf("Node %d Routing Table", node.to_i)}")

    current_y += LINE_Y_OFF

    cr.move_to(current_x, current_y)
    cr.show_text( " Target      NextHop " )
    current_y += LINE_Y_OFF

    routing_table.each do |target, nexthop|
        cr.move_to(x + RTABLE_X_OFF, current_y)
        if target and nexthop
            cr.show_text( " #{sprintf(" %d                %d ", target, nexthop)}" )
        end
        current_y += LINE_Y_OFF
    end
end


def create_topology( streams, path, theme)

    width = 2000
    height = 2000

    @options.topology = "scenario"

    draw_topology(streams, width, height, path, theme)
end

def split_trace_into_streams( file )
    hash = Hash.new
    fd = File.open(file)
    fd.readlines.each do |line|

        line.chomp!
        data = line.split(' ')

        time       = data[0].to_f
        node_index = data[1].to_i

        if hash[time] == nil
            hash[time] = Hash.new
        end

        if hash[time][node_index] == nil
            hash[time][node_index] = Hash.new
        end
        hash[time][node_index]["coordinates"] = [ data[2].to_i, data[3].to_i + 1 ]

        # Write the neighbors into the hash
        if data[4] != nil
            hash[time][node_index]["neighbors"] = data[4].split(',')
        else
            hash[time][node_index]["neighbors"] = Array.new
        end

        if data[5] != nil
            hash[time][node_index]["reachable"] = data[5].split(',')
        else
            hash[time][node_index]["reachable"] = Array.new
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

def create_video
    mencoder_opts = "vbitrate=2160000:mbd=2:keyint=132:vqblur=1.0:cmp=2:subcmp=2:dia=2:mv0:last_pred=3"
    olddir = Dir.pwd
    Dir.chdir("images")
    puts `mencoder mf://\*.png -mf w=2000:h=2000:fps=1.0:type=png -ovc lavc -lavcopts vcodec=msmpeg4v2:vpass=1:#{mencoder_opts} -oac copy -o /dev/null`
    puts `mencoder mf://\*.png -mf w=2000:h=2000:fps=1.0:type=png -ovc lavc -lavcopts vcodec=msmpeg4v2:vpass=2:#{mencoder_opts} -oac copy -o output.avi`
    puts `mv output.avi ..`
    Dir.chdir(olddir)
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
    @options.node_image = false
    @options.theme = "modern"
    @options.multimedia = false
end

# Parse options, check arguments, then process the command
def run

    require 'cairo'

    $stderr.puts("# Vanetta(C) - 2009")

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
    opts.on('-m',        '--multimedia') { @options.multimedia = true }
    opts.on('-f [format]', '--format')   { |format| @options.format = format}
    opts.on('-d [dir]',    '--directory'){ |path| @options.output_path = path}
    opts.on('-n [image]', '--node-image'){ |path| @options.node_image = path}
    opts.on('-t (modern | vehicle)', '--theme (modern | vehicle)'){ |path| @options.theme = path}

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
end

def output_usage
end

def output_version
    $stderr.puts "#{File.basename(__FILE__)} version"
end

def pr_verbose(string)
    return unless @options.verbose
    $stderr.puts "# #{string}"
end

def load_themes

    theme = Theme.new

    case @options.theme
    when "modern" # also default
        theme.canvas_bg_color        = Cairo::Color::RGB.new(52  / 255.0, 69  / 255.0, 85  / 255.0)
        theme.canvas_margin          = 250.0

        theme.node_arc_radius        = 25.0
        theme.node_arc_outline_color = Cairo::Color::RGB.new(185 / 255.0, 190 / 255.0, 194 / 255.0)
        theme.node_arc_fill_color    = Cairo::Color::RGB.new(54  / 255.0, 66  / 255.0, 78  / 255.0)

        theme.node_index_color       = :white
        theme.node_index_font_size   = 20
        theme.node_index_offset      = 10

        theme.direct_neighbor_color      = Cairo::Color::RGB.new(124 / 255.0, 138 / 255.0, 150 / 255.0)
        theme.direct_neighbor_line_width = 2.0
        theme.direct_neighbor_alpha      = 0.5

        theme.neighbor_table_bg    = Cairo::Color::RGB.new(19 / 255.0, 33 / 255.0, 44 / 255.0)
        theme.neighbor_table_alpha = 0.9
        theme.neighbor_table_color = :white
    when "vehicle"
        raise "Theme not supported"
    else
        raise "Theme not supported"
    end

    return theme
end

def process_command
    pr_verbose("trace file: #{@trace_file}")

    theme = load_themes

    streams = split_trace_into_streams( @trace_file )
    pr_verbose("streams detected: #{streams.length}")
    pr_verbose("topology creation (imagename: #{@options.topology})")

    open_output_dir(@options.output_path)
    create_topology(streams, @options.output_path, theme )

    create_video if @options.multimedia
end

# define Integer::MAX, Integer::MIN
class Integer
    N_BYTES = [42].pack('i').size
    N_BITS = N_BYTES * 8
    MAX = 2 ** (N_BITS - 2) - 1
    MIN = -MAX - 1
end

class Tool
	@@current_swirl = 0

	def Tool.pr_swirl(newtext)

		swirl = Array.[]( '-', '/', '|', '\\')

		text = sprintf("\r# %s  %-10s", swirl[@@current_swirl], newtext)

		$stderr.print text
		@@current_swirl = (@@current_swirl + 1) % 3
	end

	def Tool.swirl_exit

		tmp = " "; 80.times { tmp << " " }
		text = sprintf("\r* exiting%s\n", tmp)

		$stdout.print text
	end
end


init(ARGV, STDIN)
run
