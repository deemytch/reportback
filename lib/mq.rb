#!/usr/bin/env ruby
# encoding: utf-8

$progname = 'Sequel migration tool'
require 'bundler/setup'
require 'thor'
require 'uri'
require 'faraday'
require 'json'
require 'pry-byebug'
require_relative '../app/app'
App.config!
App.logger!
# Sequel.extension :migration

class MQtask < Thor
  package_name 'mq'

  desc "init", "Посоздавать клиентов, хосты на кролике и раздать права."
  def init
  # для управления пользуемся утилитой rabbitmqctl
    cmd = ''
    Cfg.mq.each do |bname, data|
      cmd = <<~ECMD
        rabbitmqctl add_vhost #{ data.conn.vhost }
        rabbitmqctl add_user #{ data.conn.user } #{ data.conn.password }
        rabbitmqctl set_permissions -p #{ data.conn.vhost } #{ data.conn.user } '.*' '.*' '.*'
      ECMD
      unless system("( #{ cmd } ) 2>/dev/null >/dev/null")
        puts "Ошибка выполнения команды.\n#{ cmd }\n."
      end
    end
  end

  desc 'qdel', 'Поудалять все очереди'
  def qdel
    Cfg.mq.each do |profile, data|
      Log.debug{"Удаляю все очереди из #{ data.conn.vhost }."}
      apicmd(profile, :get, "/api/queues/#{ data.conn.vhost }").each do |q|
        Log.warn{"Удаляю очередь #{ profile}/#{ q['name'] }."}
        apicmd(profile, :delete, "/api/queues/#{ data.conn.vhost }/#{ q['name'] }")
      end
    end
  end

  no_commands do
    def apicmd(profile, meth, path, hdrs = {}, data = nil)
      o = Cfg.mq[ profile ].conn.symbolize_keys.merge Cfg.mq[ profile ].api.symbolize_keys
      conn = Faraday.new(
        "http#{ o[:ssl] ? 's' : '' }://#{ o[:host] }:#{ o[:port] || 15671 }",
        { headers: { 'Content-Type' => 'application/json' }.merge(hdrs) }
      ) do |fa|
        fa.adapter  Faraday.default_adapter
        fa.basic_auth( o[:user], o[:password] )
      end
      ret = case meth
      when :get, :delete then conn.send(meth, path)
      when :post, :put, :patch then conn.send(meth, path, data)
      end
      raise "API вернул #{ ret.status }." if ret.status > 299 || ret.status < 200
      Log.debug{"Ответ: #{ ret.body }"}
      JSON.parse( ret.body ) rescue ret.body
    end
  end

end

MQtask.start
