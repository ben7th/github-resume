require 'rubygems'
require 'fssm'

directory = File.join(File.dirname(__FILE__), ARGV.first)
FSSM.monitor(directory, '**/*.haml') do
  update do |base, relative|
    input = "#{base}/#{relative}"
    output = "#{base}/#{relative.gsub!('.haml', '.html')}"
    %x{haml #{input} #{output}}
    puts "compiled #{input} to #{output}"
  end
end