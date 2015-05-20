require_relative 'redis_db.rb'
require_relative './auth/auth.rb'

#set session [protected], source
module ISet

	#set current source, function is not called if name is 'default'!
	def set_source( name, passwd )
		_r = RedisDB.instance
		_name = _r.get("passwd:#{passwd}#{name}") 	

		if _name == nil
			puts "Error: There is no such source\n"
			return false
		end

		if _name != name
			puts "Error: Wrong passwd for source #{name}\n"
			return false
		end

		RedisDB.id_src = _r.get("ssource:#{name}").to_i
		puts "Source #{name} set successfully\n"
		return true
	end

	def set_session
		_r = RedisDB.instance

		begin
			_r.watch("last_session")
			last_ses = _r.get("last_session")
			id_ses = last_ses.to_i + 1
			RedisDB.id_ses = id_ses
			_r.multi
			_r.set("last_session", id_ses)
			_r.lpush("translation_h:#{id_ses.to_s}", 0)
			_r.expireat("translation_h:#{id_ses.to_s}", Time.now.to_i + 100000)
			reply = _r.exec
		end until reply != nil

		return id_ses
	end

	module_function :set_session

	def set_protected_session( pub_key_path )
		_r = RedisDB.instance
		#expanded = File.expand_path( pub_key_path, __FILE__)
		pub_key = File.read( pub_key_path )

		begin
			_r.watch("last_session")
			last_ses = _r.get("last_session")
			id_ses = last_ses.to_i + 1
			RedisDB.id_ses = id_ses
			_r.multi
			_r.set("last_session", id_ses)
			_r.lpush("translation_h:#{id_ses.to_s}", 0)
			_r.expireat("translation_h:#{id_ses.to_s}", Time.now.to_i + 100000)
			_r.set("token:#{id_ses.to_s}", pub_key)
			_r.expireat("token:#{id_ses.to_s}", Time.now.to_i + 100000)
			reply = _r.exec
		end until reply != nil

		return id_ses
	end

	module_function :set_protected_session
end

#class Setter
#	include ISet
#end

#s = Setter.new
#s.set_source( '610', 'qwerty' )
#id_ses = s.set_protected_session( './auth/id_rsa.pem.pub' )
#Auth.ssh_auth( id_ses, './auth/id_rsa' )
