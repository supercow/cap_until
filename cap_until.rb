require 'optparse'

if Process.uid != 0
  puts "Must be run as root."
  exit 1
end

def log msg=""
  puts "[#{Time.now}] #{msg}"
end

options = {}
options[:interface] = 'eth0'
options[:prefix] = 'console_traffic_'
options[:rotate] = '300'
options[:count] = 4
options[:filter] = 'tcp port 4432 or tcp port 4430'
options[:watch_file] = "test.log"
options[:watch_regex] = / 504 /
options[:exit_wait] = options

OptionParser.new do |o|
  o.on('-i INTERFACE_DEVICE') { |r| options[:interface] = r }
  o.on('-l LOG_PREFIX') { |r| options[:prefix] = r }
  o.on('-t ROTATION_FREQUENCY', Integer) { |r| options[:rotate] = r }
  o.on('-c NUM_LOGS', Integer) { |r| options[:count] = r }
  o.on('-f CAPTURE_FILTER') { |r| options[:filter] = r }
  o.on('-r LOG_FILE') { |r| options[:watch_file] = r }
  o.on('-x FILTER_REGEX') { |r| options[:watch_regex] = r }
  o.on('-h') {puts o; exit 0}
  o.parse!
end

scan_delay = 1

@tcpdump = fork do
  system('tcpdump', '-i', options[:interface], '-w', "#{options[:prefix]}%m%d%H%M.pcap", '-G', "#{options[:rotate]}", options[:filter])
end

sleep 1 #wait for tcpdump to start
log "Started packet capture with pid #{@tcpdump}"

at_exit do
  quit_all
end

def quit_all exception=nil
  at_exit {}
  Process.kill "SIGKILL", @tcpdump + 1
  raise exception if exception != nil
  exit 0
end

# Wait to kill tcpdump and exit until at least a full rotation has passed
def delayed_exit delay=500
  sleep delay
  exit 0
end

begin
  File.open(options[:watch_file]) do |file|
    file.seek(0,IO::SEEK_END)
    checking = true
    while checking do
      sleep scan_delay
      select([file])
      line = file.gets
      if line =~ options[:watch_regex]
        log "Found matching line: #{line}"
        checking = false
      end
    end
  end
rescue Exception => e
  quit_all e
  raise e
end

delayed_exit options[:rotate]
