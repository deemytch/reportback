#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'net/http'

uri = URI '$$Cfg.http.external_url/$$report_id'

puts "Изучаю компьютер, спокойствие, только спокойствие."

puts `ruby -v`
puts `perl --version`.split("\n")[1]
puts `bash --version`.split("\n").first

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

puts 'Вычисляю свободное место, ищу чем загажен диск.'

report[:space] = `sudo du -s /* /var/* /home/*`.split("\n").sort{|a,b| b.split(/\s+/).first.to_i <=> a.split(/\s+/).first.to_i }
report[:bigfiles] = `sudo find / -xdev -type f -size +50M -exec ls -lah '{}' ';'`.split("\n")

puts "Отчёт создан, отправляю."

req = Net::HTTP::Put.new( uri )
req.body = YAML.dump report
req.content_type = 'application/yaml'
ret = Net::HTTP.start(uri.hostname, uri.port){|http| http.request(req) }
puts (ret.is_a? Net::HTTPSuccess) ?
  "Спасибо, всё хорошо." :
  "Спасибо, не получилось. Пожалуйста, сфотографируйте вывод и отправьте техподдержке."
