#!/usr/bin/ruby
# Слушать указанный обменник, очередь, канал и ключ роутинга
# Вываливать все ответы на консоль.
# Не зависит от настроек.

require 'bundler/setup'
require 'pathname'
require 'bunny'
require 'logger'
require 'yaml'
require 'optparse'
require 'msgpack'
require 'zlib'
require 'json'
require_relative '../app/app'
App.config!
App.logger!
require_relative '../app/monkeys'

cfg = {
  mq: Cfg.mq.main.conn.symbolize_keys,
  x: Cfg.mq.main.x.symbolize_keys,
  q: { name: 'amqp_listener', opts: { durable: false } },
  output: $stdout,
  listen_key: 'main.reply'
}

OptionParser.new do |opts|
  opts.banner = "#{ $0 } [options]"
  opts.on('-h', '--help', ''){  puts opts; exit }
  opts.on("-a", "--host ADDRESS", "host (#{ cfg[:mq][:host] })"){|v| cfg[:mq][:host] = v }
  opts.on("-p", "--port N", "port (#{ cfg[:mq][:port] })"){|v| cfg[:mq][:port] = v }
  opts.on("-v", "--vhost NAME", "vhost (#{ cfg[:mq][:vhost] })"){|v| cfg[:mq][:vhost] = v }
  opts.on("-u", "--username USERNAME", "(#{ cfg[:mq][:user] })"){|v| cfg[:mq][:user] = v }
  opts.on("-w", "--password PASSWORD", "(#{ cfg[:mq][:password] })"){|v| cfg[:mq][:password] = v }
  opts.on("-k", "--routing_key KEY", "listen to routing key (#{ cfg[:listen_key] })"){|v| cfg[:listen_key] = v }
  opts.on("-s", "--[no-]ssl", "need ssl? (#{ cfg[:mq][:ssl] })"){|ssl| cfg[:mq][:ssl] = ssl }
  opts.on("-x", "--exchange NAME", "exchange (#{ cfg[:x][:name] })"){|v| cfg[:x][:name] = v }
  opts.on("-t", "--xtype TYPE", "exchange type (#{ cfg[:x][:opts][:type] })"){|v| cfg[:x][:opts][:type] = v }
  opts.on("-e", "--[no-]exchange-autodelete", "exchange auto delete flag (#{ cfg[:x][:opts][:auto_delete] })"){|v| cfg[:x][:opts][:auto_delete] = v }
  opts.on("-d", "--[no-]exchange-durable", "exchange durable flag (#{ cfg[:x][:opts][:durable] })"){|v| cfg[:x][:opts][:durable] = v }
  opts.on("-q", "--queue NAME", "queue (#{ cfg[:q][:name] })"){|v| cfg[:q][:name] = v }
  opts.on("-l", "--[no-]queue-durable", "queue is durable? (#{ cfg[:q][:opts][:durable] })"){|v| cfg[:q][:opts][:durable] = v }
  opts.on("-f", "--file FILENAME", "вывод в файл (#{ cfg[:output].class.name })")do |v|
    if Pathname.new(v).dirname.exist?
      cfg[:output] = File.new(v, 'w')
    else
      raise "#{ v } не существует!"
    end
  end
end.parse!

puts "Настройки подключения:"
pp cfg
puts '-------------'

def goodbye
  Log.info{"Отключаю очередь."}
  $queue.unbind $exchange
  $queue.delete
  $rabbit.close
end

at_exit { goodbye }
trap('INT') { exit }
trap('TERM') { exit }

($rabbit  = Bunny.new( cfg[:mq].merge(logger: MQLog) )).start
$queue    = ( channel = $rabbit.create_channel ).queue( cfg[:q][:name], cfg[:q][:opts] )
$exchange = channel.exchange( cfg[:x][:name], cfg[:x][:opts] )
$queue.bind( $exchange, { routing_key: cfg[:listen_key] } )
$consumer = $queue.subscribe({ block: true }) do |di, props, body|
  # Типы объектов: мета Bunny::DeliveryInfo; заголовки Bunny::MessageProperties; тело: String.
  data = {}
  props.app_id.force_encoding('UTF-8') unless props.app_id.nil?

  if props.content_type == 'application/msgpack'
    data = MessagePack.unpack(body)
    content = Zlib::Inflate.inflate data['Content']
    content.force_encoding 'UTF-8'
    diff = Zlib::Inflate.inflate data['Diff']
    diff.force_encoding 'UTF-8'
    cfg[:output].write <<~EINSPECT
    Н-----
    #{ Time.now.strftime "%H:%M:%S:%L" }
    мета: #{ di.inspect }
    заголовки: #{ props.inspect }
    тело:
    --title
    #{ data['Title'] }
    #{ data['Timestamp'] }
    #{ data.dig('Revision','Old') } => #{ data.dig('Revision', 'New') }
    #{ data['User'] }
    #{ data['Namespace'] }
    --content:
    #{ content if content }
    
    --diff:
    #{ diff if diff }

    К-----
    EINSPECT
  elsif props.content_type == 'application/json'
    data = JSON.parse(body) rescue (data || '<<NIL>>' )
    cfg[:output].write <<~EINSPECTJSON
    Н-----
    #{ Time.now.strftime "%H:%M:%S:%L" }
    мета: #{ di.inspect }
    заголовки: #{ props.inspect }
    тело: ---
    #{ data.inspect }
    К-----
    EINSPECTJSON
  else
    cfg[:output].write <<~EINSPECT_UNKNOWN
    Н-----
    #{ Time.now.strftime "%H:%M:%S:%L" }
    мета: #{ di.inspect }
    заголовки: #{ props.inspect }
    тело: ---
    #{ body.inspect }
    К-----
    EINSPECT_UNKNOWN
  end

end

cfg[:output].close
