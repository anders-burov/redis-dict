require_relative 'redis_db.rb'
require 'csv'
require 'phonetic'
require 'russian_metaphone'

module IGet

	#search writing fuzzy or directly by value
	def search_writing( value , fuzzy = false)
		_r = RedisDB.instance
		_cyr = -1
		if (fuzzy == true)
			case (value)
			when /^\p{Cyrillic}+$/
				writing_a = _r.zrevrangebyscore("fwriting:#{RussianMetaphone::process(value)}", "+inf", "-inf", :with_scores=>true)
				_cyr = 1
			when /^[A-Za-z]+$/
				writing_a = _r.zrevrangebyscore("fwriting:#{value.refined_soundex}", "+inf", "-inf", :with_scores=>true)
				_cyr = 0
			else
				puts "Error: The writing contains neither latin xor cyrillic characters.\n"
				return false
			end
		else
			if (value =~ /^\p{Cyrillic}+|[A-Za-z]+$/)
				writing_a = _r.zrevrangebyscore("swriting:#{value}", "+inf", "-inf", :with_scores=>true)
			else
				puts "Error: The writing contains neither latin xor cyrillic characters.\n"
				return false
			end
		end

		count = 1
		headers = ['1:Number', '2:Lookups', '3:Value', '4:Language', '5:Speechpart']
		hr = CSV::Row.new( headers, headers, true )
		table = CSV::Table.new( [hr] )
		mem = [ 0 ] #THERE MUST BE NO WRITING WITH THIS ID!
		writing_a.each do |(id_wr, score)|
			wr = _r.hmget("writing:#{id_wr}", "value", "lang", "sp")
			row = CSV::Row.new(headers, [ count, score, wr[0], RedisDB.n_lg[ wr[1].to_i ], RedisDB.n_sp[ wr[2].to_i ] ])
			table.push(row)
			mem.push(id_wr)
			count+=1
		end

		RedisDB.table_prefix = (fuzzy) ? 'fwriting' : 'swriting'
		if (_cyr == 1) then RedisDB.table_postfix = RussianMetaphone::process(value)
		elsif (_cyr == 0) then RedisDB.table_postfix = value.refined_soundex
		else RedisDB.table_postfix = value end
		RedisDB.mem = mem

		return table, 5
	end

	def search_source( name, fuzzy = false )
		unless name =~ /^[A-Za-z0-9]+$/
			puts "Error: The writing contains neither latin xor cyrillic characters.\n"
			return false
		end

		_r = RedisDB.instance
		if (fuzzy == true)
				source_a = _r.zrevrangebyscore("fsource:#{name.refined_soundex}", "+inf", "-inf", :with_scores=>true)
		else
				source = _r.get("ssource:#{name}")
				source_a = [[source, 'x']]
		end

		count = 1
		id = 0
		headers = ['1:Number', '2:Lookups', '3:Value', '4:Comment']
		hr = CSV::Row.new( headers, headers, true )
		table = CSV::Table.new( [hr] )
		mem = [ 0 ] if fuzzy == true # THERE MUST BE NO TRANSLATION WITH THIS ID!
		source_a.each do |(id_src, score)|
			src = _r.hmget("source_d:#{id_src}", "name", "comment")
			row = CSV::Row.new(headers, [ count, score, src[0], src[1] ])
			table.push(row)
			mem.push(id_src) if fuzzy == true
			id = id_src if fuzzy == false
			count+=1
		end

		RedisDB.table_prefix = (fuzzy) ? 'fsource' : 'ssource'
		RedisDB.table_postfix = (fuzzy) ? name.refined_soundex : name
		if fuzzy == true
			RedisDB.mem = mem
		else
			RedisDB.mem = [0, id]
		end

		return table, 4
	end

	#by default retun reverse order list of sources translations
	#pass 0 to get each
	def get_list_of_source( id_src, amount = 10, directly = false )
		_r = RedisDB.instance
		if directly == false
			list = _r.lrange("translations_of_source:#{id_src}", 0, amount-1);
		else
			list = _r.lrange("translations_of_source:#{id_src}", -amount, -1);
			list = list.reverse
		end

		count = 1
		headers = ['1:Number', '2:Word', '3:Language', '4:Word', '5:Language', '6:Comment']
		hr = CSV::Row.new( headers, headers, true )
		table = CSV::Table.new( [hr] )
		list.each do |(id_tr)|
			tr = _r.hmget("translation_d:#{id_tr}", "a", "b", "comment")
			a = _r.hgetall("writing:#{tr[0]}")
			b = _r.hgetall("writing:#{tr[1]}")
			row = CSV::Row.new(headers, [ count, a['value'], RedisDB.n_lg[ a['lang'].to_i ], \
																 b['value'], RedisDB.n_lg[ b['lang'].to_i ], tr[2] ])
			table.push(row)
			count+=1
		end

		RedisDB.table_prefix = 'translations_of_source'
		RedisDB.table_postfix = id_src.to_s

		return table, 6
	end

	def translate( id_wr )
		_r = RedisDB.instance
		tran_a = _r.zrevrangebyscore("translation:#{id_wr}", "+inf", "-inf", :with_scores => true)
		count = 1
		headers = ['1:Number', '2:Lookups', '3:Word', '4:Language', '5:Word', '6:Language', '7:Comment']
		hr = CSV::Row.new( headers, headers, true )
		table = CSV::Table.new( [hr] )
		mem = [ 0 ] # THERE MUST BE NO TRANSLATION WITH THIS ID!
		tran_a.each do |(id_tr, score)|
			tr = _r.hmget("translation_d:#{id_tr}", "a", "b", "comment")
			a = _r.hgetall("writing:#{tr[0]}")
			b = _r.hgetall("writing:#{tr[1]}")
			row = CSV::Row.new(headers, [ count, score, a['value'], RedisDB.n_lg[ a['lang'].to_i ], \
																 b['value'], RedisDB.n_lg[ b['lang'].to_i ], tr[2] ])
			table.push(row)
			mem.push(id_tr)
			count+=1
		end

		RedisDB.table_prefix = 'translation'
		RedisDB.table_postfix = id_wr.to_s
		RedisDB.mem = mem

		return table, 7
	end

	def source_of_translation( id_tr )
		_r = RedisDB.instance
		source_a = _r.zrevrangebyscore("source_of_translation:#{id_tr}", "+inf", "-inf", :with_scores => true)
		count = 1
		headers = ['1:Number', '2:Lookups', '3:Name', '4:Comment']
		hr = CSV::Row.new( headers, headers, true )
		table = CSV::Table.new( [hr] )
		mem = [ 0 ] # THERE MUST BE NO SOURCE WITH THIS ID!
		source_a.each do |(id_src, score)|
			src = _r.hgetall("source_d:#{id_src}")
			row = CSV::Row.new(headers, [ count, score, src['name'], src['comment']	])
			table.push(row)
			mem.push(id_src)
			count+=1
		end

		RedisDB.table_prefix = 'source_of_translation'
		RedisDB.table_postfix = id_tr.to_s
		RedisDB.mem = mem

		return table, 4
	end
end

#class Getter
#	include IGet
#end
#
#g = Getter.new
#g.train('пкуут')
#g.search_source('610')
#g.get_list_of_source( 2, 10 )
#g.translate( 2 )
#g.source_of_translation( 1 )
