# cap\_until

Run tcpdump until a regex appears in a file.

This script is primarily useful for generating packet captures when attempting
to diagnose intermittent issues. Run the script specifying a log file and a
regex, and it will spawn a tcpdump process that will quit some interval (default
2 minutes) after the regex matches.

This script will scan to the end of the file on startup, so only *new* matching
entries will stop the capture.

## Examples

```
root@server:~# /opt/puppetlabs/puppet/bin/ruby cap_until.rb -i en0 -t 5 -x ' 503 ' -r test.log
tcpdump: listening on en0, link-type EN10MB (Ethernet), capture size 65535 bytes
[2017-02-14 12:40:05 -0500] Started packet capture with pid 22288
[2017-02-14 12:40:05 -0500] Watching file test.log for / 503 /
[2017-02-14 12:40:20 -0500] Matched line: Server encountered 503 error
[2017-02-14 12:40:20 -0500] Exiting in 5 seconds
[2017-02-14 12:40:25 -0500] Exiting.
root@server:~# ls
console_traffic_02141240.pcap
root@server:~#
```
