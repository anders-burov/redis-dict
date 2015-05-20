require 'redis'

module RedisDB
	class << self
		def instance
			@instance ||= init_instance
			return @instance
		end

		attr_reader :sp_n
		attr_reader :n_sp
		attr_reader :lg_n
		attr_reader :n_lg
		attr_accessor :id_src
		attr_accessor :id_ses
		attr_accessor :twlq
		attr_accessor :table
		attr_accessor :nf
		attr_accessor :mem
		attr_accessor :table_prefix
		attr_accessor :table_postfix
		attr_accessor :file

		private
		def init_instance
			@instance = Redis.new
			_sp_a = @instance.zrange("sp", 0, -1, :with_scores => true)
			@sp_n = {}
			_sp_a.each { |(sp, n)| @sp_n[sp] = n.to_i }
			@n_sp = []
			_sp_a.each { |(sp, n)| @n_sp.push sp }
			_lg_a = @instance.zrange("lang", 0, -1, :with_scores => true)
			@lg_n = {}
			_lg_a.each { |(lg, n)| @lg_n[lg] = n.to_i }
			@n_lg = []
			_lg_a.each { |(lg, n)| @n_lg.push lg }
			@mem = []
			@twlq = false
			@id_src = 1
			return @instance
		end
	end
end
