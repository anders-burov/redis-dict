require 'optparse'
require 'ostruct'

class OptionExtracter
	def self.parse(options)
		args = OpenStruct.new

		opt_parser = OptionParser.new do |opts|
			opts.banner = "USAGE: opt.rb [-p pub|-i id -r priv] [--file FILE]"

			opts.on("-i", "--id" " Id of existing session") do |id|
				args.id = id
			end

			opts.on("-p", "--pub" " Public key path") do |pub|
				args.pub = pub
			end

			opts.on("-r", "--prv" " Private key path") do |prv|
				args.prv = prv
			end

			opts.on("-f" "--file" " File with commands") do |file|
				args.file = file
			end

			opts.on("-h", "--help", " Prints this help") do
				puts opts
				exit
			end
		end

		opt_parser.parse!(options)
		return args
	end
end
