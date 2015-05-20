require_relative 'redis_db.rb'
require 'phonetic'
require 'russian_metaphone'

#add writing, source, translation
module IAdd
	# check if id_wr writing has equal fields with value, lang, sp 
	def is_equal_writing(	id_wr, value, lang, sp )
		_r = RedisDB.instance
		writing_d = _r.hmget("writing:#{id_wr}", "value", "lang", "sp")

		return false if writing_d[0] != value	
		return false if writing_d[1] != lang.to_s
		return false if writing_d[2] != sp.to_s
		puts "Error: writing #{value} is already there!\n"
		return true
	end

	#check if between given writings does not exist translation
	def is_unique_translation( id_wr_1, id_wr_2 )
			_r = RedisDB.instance

			count_1 = _r.zcount("translation:#{id_wr_1}", "-inf", "+inf")
			count_2 = _r.zcount("translation:#{id_wr_2}", "-inf", "+inf")
			
			if count_1 >= count_2
				tran_a = _r.zrevrangebyscore("translation:#{id_wr_2}", "+inf", "-inf")
				tran_a.each do |el|
					if id_wr_1.to_s == _r.hget("translation_d:#{el}", "a")
						puts "Error: This translation already exists!\n"
						return false
					end
				end
			else
				tran_a = _r.zrevrangebyscore("translation:#{id_wr_1}", "+inf", "-inf")
				tran_a.each do |el|
					if id_wr_1.to_s == _r.hget("translation_d:#{el}", "a")
						puts "Error: This translation already exists!\n"
						return false
					end
				end
			end

			return true
	end

	def add_writing( value, lang, sp )
		_r = RedisDB.instance

		lang_n = RedisDB.lg_n[lang] || begin puts "language not supported!\n"; return false; end
		sp_n = RedisDB.sp_n[sp] || begin puts "speechpart not supported!\n"; return false; end	

		#check unique
		until _r.setnx("insert_w:#{value}", 1) == true do sleep 0.1 end

		writing_a = _r.zrevrangebyscore("swriting:#{value}", "+inf", "-inf")
		writing_a.each do |id_wr|
			if is_equal_writing( id_wr, value, lang_n, sp_n )
				_r.del("insert_w:#{value}")
				return false, id_wr
			end
		end

		#insert atomically
		begin
			_r.watch("last_writing")
			last_wr = _r.get("last_writing")
			id_wr = last_wr.to_i + 1
			_r.multi
			_r.hmset("writing:#{id_wr}", "value", "#{value}", "lang", "#{lang_n}", "sp", "#{sp_n}")
			_r.set("last_writing", id_wr)
			_r.del("insert_w:#{value}")
			reply = _r.exec
		end until reply != nil

		#make_writing_searchable
		_r.zadd("swriting:#{value}", 0, id_wr)
		case lang
		when "ru"
			_r.zadd("fwriting:#{RussianMetaphone::process(value)}", 0, id_wr)
		else
			_r.zadd("fwriting:#{value.refined_soundex}", 0, id_wr)
		end

		return true, id_wr
	end

	def add_translation( val_1, lang_1, sp_1, val_2, lang_2, sp_2, comment )
		
		#series of checks, based on DB rules
		if val_1 == val_2
			puts "Error: We do not support equal writings\n"
			return false
		end

		if sp_1 != sp_2
			puts "Error: We do not support translation between different speechparts\n"
			return false
		end

		if lang_1 == lang_2
			puts "Error: We do not support translations in the same language\n"
			return false
		end

		_r = RedisDB.instance

		lang_n1 = RedisDB.lg_n[lang_1] || begin puts "language not supported!\n"; return false; end
		lang_n2 = RedisDB.lg_n[lang_2] || begin puts "language not supported!\n"; return false; end

		if lang_n1 > lang_n2
			val_1,lang_1,sp_1,val_2,lang_2,sp_2=val_2,lang_2,sp_2,val_1,lang_1,sp_1
		end

		res_1, id_wr_1 = add_writing( val_1, lang_1, sp_1 )
		res_2, id_wr_2 = add_writing( val_2, lang_2, sp_2 )

		if (res_1 || res_2) == false
			#check unique translation
			until _r.setnx("insert_t:#{val_1}-#{val_2}", 1) == true do sleep 0.1 end
			
			unless is_unique_translation( id_wr_1, id_wr_2 )
				_r.del("insert_t:#{val_1}-#{val_2}")
				return false
			end	
		end

		#insert atomically
		begin
			_r.watch("last_translation")
			last_tr = _r.get("last_translation")
			id_tr = last_tr.to_i + 1
			_r.multi
			_r.hmset("translation_d:#{id_tr}", "a", "#{id_wr_1}", "b", "#{id_wr_2}", "comment", "#{comment}")
			_r.set("last_translation", id_tr)
			_r.del("insert_t:#{val_1}-#{val_2}")
			reply = _r.exec
		end until reply != nil

		id_src = RedisDB.id_src.to_s 

		_r.multi
		#add to source
		_r.lpush("translations_of_source:#{id_src}", id_tr)
		_r.zadd("source_of_translation:#{id_tr}", 0, id_src)
		#add to writing
		_r.zadd("translation:#{id_wr_1}", 0, id_tr)
		_r.zadd("translation:#{id_wr_2}", 0, id_tr)
		_r.exec

		return true
	end

	def add_source( name, passwd, comment )
		_r = RedisDB.instance

		#check unique
		until _r.setnx("insert_s:#{name}", 1) == true do sleep 0.1 end

		if _r.get("ssource:#{name}") != nil
			puts "Error: This source name is already registered\n"
			_r.del("insert_s:#{name}")
			return false
		end

		#insert atomically
		begin
			_r.watch("last_source")
			last_src = _r.get("last_source")
			id_src = last_src.to_i + 1
			_r.multi
			_r.hmset("source_d:#{id_src}", "name", "#{name}", "comment", "#{comment}")
			_r.set("last_source", id_src)
			_r.set("passwd:#{passwd}#{name}", "#{name}")
			_r.del("insert_s:#{name}")
			reply = _r.exec
		end until reply != nil

		#make source searchable
		_r.set("ssource:#{name}", id_src)
		_r.zadd("fsource:#{name.refined_soundex}", 0, id_src)

		return id_src
	end
end

#class Adder
#	include IAdd
#end
#
#a = Adder.new
#a.add_writing('green', 'en', 'verb')
#a.add_source('default', 'qwerty', 'It is default')
#a.add_translation('зелёный', 'ru', 'adjective', 'green', 'en', 'adjective', 'it\'s going to be first')
