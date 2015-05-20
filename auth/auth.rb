require 'securerandom'
require_relative '../redis_db.rb'

module Auth
	def self.ssh_auth( id_ses, priv_key_path )
		_r = RedisDB.instance
		pub_key = _r.get("token:" << id_ses.to_s)
		File.open("pub_key", "w+") { |f| f << pub_key }
		File.open("pas_msg", "w+") { |f| f << SecureRandom.hex }
		`openssl rsautl -encrypt -pubin -inkey pub_key -ssl -in pas_msg \
		-out enc_msg`
		`openssl rsautl -decrypt -inkey #{priv_key_path} -in enc_msg \
	 	-out dec_msg`

		if ( `diff -q pas_msg dec_msg` != "" )
			`rm pub_key pas_msg enc_msg dec_msg`
			puts "Error: You failed the authorisation!"
			return false
		elsif
			`rm pub_key pas_msg enc_msg dec_msg`
			RedisDB.id_ses = id_ses
			puts "You authorised succesfully! With id = #{id_ses}"
			return true
		end
	end
end
