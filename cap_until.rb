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
options[:rotate] = 120
options[:count] = 4
options[:filter] = 'tcp port 4432 or tcp port 4430 or tcp port 8081'
options[:watch_file] = "/var/log/puppetlabs/nginx/access.log"
options[:watch_regex] = / 504 /
options[:exit_wait] = options

OptionParser.new do |o|
  o.banner = "Runs a packet capture until a maching log entry is found\n\nUsage: #{$PROGRAM_NAME} [options]\nAll arguments are optional.\n\nOptions:"
  o.on("-i INTERFACE_DEVICE (default: #{options[:interface]}") { |r| options[:interface] = r }
  o.on("-l LOG_PREFIX (default: #{options[:prefix]})") { |r| options[:prefix] = r }
  o.on("-t ROTATION_FREQUENCY (default: #{options[:rotate]})", Integer) { |r| options[:rotate] = r }
  o.on("-c NUM_LOGS (default: #{options[:count]}", Integer) { |r| options[:count] = r }
  o.on("-f CAPTURE_FILTER (default: #{options[:filter]})") { |r| options[:filter] = r }
  o.on("-r LOG_FILE (default: #{options[:watch_file]})") { |r| options[:watch_file] = r }
  o.on("-x FILTER_REGEX (default: #{options[:watch_regex].inspect})") { |r| options[:watch_regex] = Regexp.new r }
  o.on("-h","--help") {puts o; exit 0}
  o.parse!
end

scan_delay = 1

@tcpdump = Process.spawn(
  'tcpdump', '-z', 'gzip', '-i', options[:interface], '-w', "#{options[:prefix]}%m%d%H%M.pcap", '-G', "#{options[:rotate]}", options[:filter]
)
Process.detach @tcpdump

sleep 1 #wait for tcpdump to start
log "Started packet capture with pid #{@tcpdump}"

def quit_all retval=0, exception=nil
  begin
    Process.kill "SIGKILL", @tcpdump
    log "Exiting."
  rescue Errno::ESRCH
  end
  raise exception if exception != nil
  exit retval
end

at_exit do
  quit_all 1 if !($!.is_a?(SystemExit))
end

# Wait to kill tcpdump and exit until at least a full rotation has passed
def delayed_exit delay=300
  log "Exiting in #{delay} seconds"
  sleep delay
  quit_all
end

begin
  File.open(options[:watch_file]) do |file|
    file.seek(0,IO::SEEK_END)
    checking = true
    log "Watching file #{options[:watch_file]} for #{options[:watch_regex].inspect}"
    while checking do
      sleep scan_delay
      select([file])
      line = file.gets
      if line =~ options[:watch_regex]
        log "Matched line: #{line}"
        checking = false
      end
    end
  end
rescue Exception => e
  quit_all 1, e
  raise e
end

delayed_exit options[:rotate]
