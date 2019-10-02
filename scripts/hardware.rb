#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'net/http'

def assert( report, consolemsg = '', &block )
  unless yield
    errormsg( report )
    raise consolemsg
  end
end

def send_report( uri, report, content_type = :yaml )
  return true if report.nil? || report.empty?
  puts "Отправляю отчёт (#{ content_type })."
  req = Net::HTTP::Put.new( uri )
  use_ssl = uri.scheme == 'https'
  case content_type
  when :yaml
    req.body = YAML.dump( report )
    req.content_type = 'application/yaml'
  when :plain
    req.body = report
    req.content_type = 'text/plain'
  end
  ret = Net::HTTP.start( uri.hostname, uri.port, :use_ssl => use_ssl ){ |http| http.request(req) }
  unless ret.is_a?( Net::HTTPSuccess )
    puts "#{ ret }, #{ ret.body }\n---\n"
  end
  !! ret.is_a?( Net::HTTPSuccess )
end

def errormsg( install_log )
  puts send_report( URI( '$$Cfg.http.external_url/r/$$report_id/install_log' ), File.read( install_log ), :plain ) ?
  "Лог неудачной установки отправлен" :
  "Ошибка отправки лога неудачной установки"
  puts "\n\n\n\tСлучилась ошибка. Отправьте снимок экрана, пожалуйста техподдержке.\n\n\n"
end

## Специально, если обломается на любой строчке
puts "Изучаю компьютер, спокойствие, только спокойствие."
puts <<-DIAG0
#{ `uname -a`.chomp }
#{ `ps axu|grep vpn|grep -v grep`.chomp }
#{ `ruby -v`.chomp }
#{ `perl --version`.split("\n")[1].chomp }
#{ `bash --version`.split("\n").first.chomp }
DIAG0

report = { :hostname => `hostname 2>&1`,
           :uptime => `uptime 2>&1`,
           :cpu => File.read('/proc/cpuinfo'),
           :ip => `ip a 2>&1`,
           :resolv => File.read('/etc/resolv.conf'),
           :hosts => File.read('/etc/hosts'),
           :passwd => File.read('/etc/passwd'),
           :uname => `uname -a 2>&1`,
           :mem => `free 2>&1`,
           :usb => `lsusb 2>&1`,
           :pci => `lspci 2>&1`,
           :lsb => `lsb_release -a 2>&1`,
           :mount => `mount 2>&1`.split("\n"),
           :df => `df -h`.split("\n"),
           :disks => Hash[
              *( Dir['/dev/sd?', '/dev/vd?', '/dev/hd?'].
                  collect{|disk|
                    [ disk, {
                      :fdisk => `sudo fdisk -l #{ disk } 2>&1`,
                      :hdparm => `sudo hdparm -i #{ disk } 2>&1`
                      } 
                    ]
                  }.flatten
                ) ],
           :traceroute => `tracepath $$Cfg.http.ping_host 2>&1`,
           :authkeys => Hash[ *(
              Dir['/home/*'].collect{|folder| [ folder, `sudo cat #{ folder }/.ssh/authorized_keys 2>&1` ] }.flatten
            )],
           :env => ENV,
           :ruby => `ruby -v`,
           :perl => `perl --version`[/v[^ ]+/],
           :bash => `bash --version`.split("\n").first,
           :sshconf => File.read('/etc/ssh/sshd_config')
        }
report[:authkeys][:root] = `sudo cat /root/.ssh/authorized_keys 2>&1`

puts "\tВычисляю свободное место."

report[:space] = `sudo du -s /* /var/* /home/* 2>&1`.split("\n").sort{|a,b| b.split(/\s+/).first.to_i <=> a.split(/\s+/).first.to_i }
report[:bigfiles] = `sudo find / -xdev -type f -size +50M -exec ls -lah '{}' ';' 2>&1`.split("\n")

assert( '', "\n\n\tНе получилось отправить отчёт.\n\tПожалуйста, сфотографируйте вывод\n\tи отправьте техподдержке в WhatsApp +7(927)954-66-71.\n\n" ) do
  send_report( URI( "$$Cfg.http.external_url/r/$$report_id" ), report )
end

puts "\tОтчёт отправлен. Перехожу к установке VPN."

install_log = "/tmp/install_log-$$report_id"

# Запускаем установку VPN
uri = URI( "$$Cfg.http.external_url/i/$$report_id" )
req = Net::HTTP::Get.new( uri )
ret = Net::HTTP.start( uri.hostname, uri.port, :use_ssl => ( uri.scheme == 'https' ) ){ |http| http.request(req) }

assert( install_log, "#{ ret }, #{ ret.body }\n\n" ) { ret.is_a?( Net::HTTPSuccess ) }

File.open('/tmp/install.sh', 'w'){ |f| f.write ret.body.force_encoding('UTF-8') }
`chmod +x /tmp/install.sh`
assert( install_log ){ system "sudo /bin/bash -l -c /tmp/install.sh >#{ install_log } 2>&1" }

File.open( install_log, 'a'){|log| log.write "\n" + `ps axu`.split("\n").select{ |l| l =~ /openvpn/ }.join }
assert( install_log ){ system 'ping -q -c5 10.10.0.1 2>&1' }

puts "Все хорошо. Спасибо. Можно переключаться на веб-интерфейс.\n\t\tCtrl-D\n\t\tCtrl-Alt-F7\n\n"
