#!/usr/bin/env ruby

def help
  puts "usage ..."
end

def start
  run 'start'
end

def stop
  run 'stop'
end

def restart
  run 'restart'
end

def status
  pid_filename = "tmp/kibana.rb.pid"
  if (File::exists?(pid_filename)) then
    File.open(pid_filename) { |file|
      pid = file.readline().to_i
      puts "pid is #{pid}"
      begin
        Process.getpgid(pid)
        return true
      rescue Errno::ESRCH
        return false
      end
    }
  else
    return false
  end
end

def run(cmd)
  system "ruby kibana-daemon.rb #{cmd}"
end

if (ARGV.length == 0) then
  help
else
  case ARGV[0]
    when "start"
      start
      exit (status) ? 0 : 1
    when "stop"
      stop
      exit (status) ? 1 : 0
    when "restart"
      restart
      exit (status) ? 0 : 1
    when "status"
      exit (status) ? 0 : 1
    else
      help
      exit 1
  end
end
