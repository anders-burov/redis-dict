require 'redis'

$r = Redis.new
$sp_a = $r.zrange("sp", 0, -1, :with_scores => true)
$sp_n = {}
$sp_a.each { |(sp, n)| $sp_n[sp] = n.to_i }
$n_sp = []
$sp_a.each { |(sp, n)| $n_sp.push sp }

def add_translations(file, n, i)
	i.times do |oo|
		script = ""
		n.times do |ooo|
			sp = $n_sp[rand($n_sp.size)]
			cmd = "at #{(0...8).map { (65 + rand(26)).chr }.join} pf #{sp} #{(0...8).map { (65 + rand(26)).chr }.join} te #{sp}\n"
			script = script << cmd
		end

		File.open(file, "w+") { |f| f << script }
	end
end	

add_translations("cmd.txt", 1000, 1000)
