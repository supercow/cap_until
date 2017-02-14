if Process.uid != 0
  puts "Must be run as root."
end

def log msg=""
  puts "[#{Time.now}] #{msg}"
end

#device ||= 'eth0'
device ||= 'en0'
prefix ||= 'console_traffic'
rotate ||= '300'
filter ||= 'tcp port 4432 or tcp port 4430'
watch_file ||= "test.log"
watch_regex ||= / 504 /
scan_delay = 1

@tcpdump = fork do
  system('tcpdump', '-i', device, '-w' "#{prefix}%m%d%H%M.pcap", '-G', rotate, filter)
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
  exit 1
end

def delayed_exit delay=5
  sleep delay
  exit 0
end

begin
  File.open(watch_file) do |file|
    file.seek(0,IO::SEEK_END)
    checking = true
    while checking do
      sleep scan_delay
      select([file])
      line = file.gets
      if line =~ watch_regex
        log "Found matching line: #{line}"
        checking = false
      end
    end
  end
rescue Exception => e
  quit_all e
  raise e
end

delayed_exit
