#!/usr/bin/env ruby

def help
  puts "usage ..."
end

def start
  while(!status)
    run 'start'
  end
end

def stop
  run 'stop'
end

def restart
  run 'restart'
end

def status(repeat=0)
  sleep 2
  (0..repeat).each { |n|
    pid_filename = "tmp/kibana.rb.pid"
    if (File::exists?(pid_filename)) then
      File.open(pid_filename) { |file|
        pid = file.readline().to_i
        puts "pid is #{pid}"
        begin
          Process.getpgid(pid)
          puts 'running'
          return true
        rescue Errno::ESRCH
          puts 'not running'
          return false
        end
      }
    else
      if(n == repeat)
        return false
      else
        print '.'
        sleep 1
      end
    end
  }
  return
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
      exit (status 5) ? 0 : 1
    when "stop"
      stop
      exit (status) ? 1 : 0
    when "restart"
      restart
      exit (status 5) ? 0 : 1
    when "status"
      exit (status) ? 0 : 1
    else
      help
      exit 1
  end
end
