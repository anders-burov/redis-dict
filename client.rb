require_relative 'redis_db.rb'
require_relative 'add.rb'
require_relative 'set.rb'
require_relative 'get.rb'
require_relative './auth/auth.rb'
require_relative 'opt.rb'

class Client
	include IGet
	include ISet
	include IAdd
	
	def initialize argv
		opt = OptionExtracter.parse(argv)

		RedisDB.id_ses = 0

		if (defined?(opt.pub) == nil && \
				defined?(opt.prv) != nil && \
				defined?(opt.id ) != nil)
			if Auth.ssh_auth( opt.id, opt.prv )
				RedisDB.id_ses = opt.id
			else
				exit
			end
		end

		if (defined?(opt.pub) != nil && \
				defined?(opt.prv) == nil && \
				defined?(opt.id ) == nil)
			RedisDB.id_ses = set_protected_session(opt.pub)
		end

		if (defined?(opt.pub) == nil && \
				defined?(opt.prv) == nil && \
				defined?(opt.id ) == nil)
			RedisDB.id_ses = set_session
		end

		if RedisDB.id_ses == 0
			puts "You have not entered\n"
			exit
		end

		if (defined?(opt.file) != nil)
			RedisDB.file = opt.file
			puts "The commands are going to be parsed from #{RedisDB.file}"
		end

		_r = RedisDB.instance
		@prompt = "id:#{RedisDB.id_ses}> ".chomp
		puts "You have successfully entered\n"
	end

	#print to screen
	def print_table( table, number_of_fields )
		table.each do |row|
			for elem in row.fields(0...number_of_fields) do
				printf "%-12s ", elem
			end
			printf "\n"
		end

		RedisDB.twlq = true
		RedisDB.table = table
		RedisDB.nf = number_of_fields
	end

	#increase Lookups number for the current line
	def rate_line( line_num )
		table = RedisDB.table
		table.by_row!
		h = []
		table[0].to_a.each { |e| h.push(e[0]) }
		head = CSV::Row.new(h, h, true)
		l = []
		table[line_num].to_a.each { |e| l.push(e[1]) }
		line = CSV::Row.new(h, l)
		some = line['2:Lookups'].to_i
		some += 1
		line['2:Lookups'] = some	
		rtable = CSV::Table.new([head])
		rtable.push(line)
		_r = RedisDB.instance
		_r.zincrby(RedisDB.table_prefix << ":#{RedisDB.table_postfix}", 1, RedisDB.mem[line_num].to_s)
		_r.lpush("translation_h:#{RedisDB.id_ses.to_s}", RedisDB.mem[line_num]) if RedisDB.table_prefix == 'translation'

		return rtable
	end

	#filter by row (field == 0), or by specified field
	def filter_table( field, regex )
		table = RedisDB.table
		table.by_row!
		ftable = CSV::Table.new([table[0]])
		count = 0

		if field == 0
			table.each do |row|
				if count == 0 then count += 1; next; end
				if row.to_s.chomp.tr(',',' ')	=~ /#{Regexp.quote(regex)}/
					ftable.push(table[count])
				end
				count += 1
			end
		else
			field -= 1
			table.each do |row|
				if count == 0 then count += 1; next; end
				if row[field] =~ /#{Regexp.quote(regex)}/
					ftable.push(table[count])
				end
				count += 1
			end
		end

		return ftable
	end
	
	#wrong keyboard layout
	def train( value )
		case value
		when	/^\p{Cyrillic}+$/
			return value.tr('ЁёЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮйцукенгшщзхъфывапролджэячсмитьбю', \
							 '~`QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>qwertyuiop[]asdfghjkl;\'zxcvbnm,.')
		else
			return value.tr('~`QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>qwertyuiop[]asdfghjkl;\'zxcvbnm,.', \
										 'ЁёЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮйцукенгшщзхъфывапролджэячсмитьбю')
		end
	end

	def parse( input )
		case input[0]
		when "q","quit"
			return "q"
		when "sw","search-writing"
			table, nf = search_writing(input[1])	
			print_table table, nf
		when "fw","fuzzy-writing"
			table, nf = search_writing(input[1], true)
			print_table table, nf
		when "tw","train-writing"
			tr = train(input[1])
			table, nf = search_writing(tr)
			print_table table, nf
		when "ss","search-source"
			table, nf = search_source(input[1])
			print_table table, nf
		when "fs","fuzzy-source"
			table, nf = search_source(input[1], true)
			print_table table, nf
		when "ld","list-translations-directly"
			unless (RedisDB.table_prefix == "ssource" ||
						RedisDB.table_prefix == "fsource")
				puts "Note: You have to choose the source first"
			else
				table, nf = get_list_of_source(RedisDB.mem[input[1].to_i], input[2].to_i, true)	
				print_table table, nf
			end
		when "lr","list-translations-reversly"
			unless (RedisDB.table_prefix == "ssource" ||
						RedisDB.table_prefix == "fsource")
				puts "Note: You have to choose the source first"
			else
				table, nf = get_list_of_source(RedisDB.mem[input[1].to_i], input[2].to_i, false)	
				print_table table, nf
			end
		when "t"
			unless (RedisDB.table_prefix == "swriting" ||
					RedisDB.table_prefix == "fwriting")
				puts "Note: You have to search a writing first!"
			else
				table, nf = translate(RedisDB.mem[input[1].to_i])
				print_table table, nf
			end
		when "s","source-of-translation"
			unless (RedisDB.table_prefix == "translation")
				puts "Note: You have to find translation first"
			else
				table, nf = source_of_translation(RedisDB.mem[input[1].to_i])
				print_table table, nf
			end
		when "at","add-translation"
			if add_translation(input[1], input[2], input[3], input[4], input[5], input[6], input[7])
				puts "You added translation successfully" 
			else
			 puts "You failed to add translation"	 
			end
			RedisDB.twlq = false
		when "as","add-source"
			if add_source(input[1], input[2], input[3])
				puts "You added source successfully"
			else
				puts "you failed to add source"
			end
		when "set","set-source"
			set_source(input[1], input[2])
		when "f","filter"
			if RedisDB.twlq == false
				puts "Note: You can not filter not a table!"
			else
				if RedisDB.nf >= input[1].to_i && input[1].to_i >= 0
					table = filter_table(input[1].to_i, input[2])
					print_table table, RedisDB.nf
				else
					puts "Note: You have to choose between 0 and #{RedisDB.nf}"
				end
			end
		when /^[0-9]+$/
			if RedisDB.twlq == false
				puts "Note: You can not rate line in not a table"
			else
				if RedisDB.table.size > input[0].to_i && input[0].to_i > 0
					if (RedisDB.table_prefix == 'translations_of_source' || \
						RedisDB.table_prefix == 'ssource')
						puts "Note: You can not rate line for that table"
					else
						table = rate_line(input[0].to_i)
						print_table table, RedisDB.nf
					end
				else
					puts "Note: You have to choose between 1 and #{RedisDB.table.size}"
				end
			end
		else
			puts "Tricky you!\n"
			return "q"
		end
	end

	def run
		unless RedisDB.file != nil
			begin
				print "#{@prompt}"	
				res = parse(gets.chomp.split(' '))
			end until res == "q"
		else
			File.open(RedisDB.file, "r") do |infile|
				while (line = infile.gets)
					res = parse(line.chomp.split(' '))
				end 
			end
		end
	end
end

if __FILE__ == $0
	c = Client.new(ARGV)
	c.run
	puts "You successfully finished\n"
end
