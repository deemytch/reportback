require_relative 'report'
require_relative 'monkeys'

## Вызывается из Rack::Server

class ReportServer
  # содержимое ответа той стороной не проверяется
  def call(env)
    request = Rack::Request.new(env)
    payload = YAML.load(request.body.read)
    Log.info{"#{ request.user_agent }:#{ request.ip } #{ request.request_method } #{ request.path }\ncontent-type: #{ request.content_type }\n#{ payload ? payload : '-' }\n===."}

    # return respond(:ok)
    return respond(:ok) if request.user_agent =~ /WhatsApp|Viber/i
    
    if request.put? && request.path =~ %r{/r/(\d+)}
      report_id = $1
      r = Report[ report_id ]
      unless r
        Log.error{"Запрошено обновление неизвестного отчёта #{ report_id }."}
        return respond(:invalid)
      end

      Log.info{"Update #{ report_id } => #{ request.ip }, #{ payload[:hostname] }."}
      Report[ report_id ].update( hardware: payload, ip: request.ip )
      return respond(:ok)

    # Запрос скрипта установки vpn
    elsif request.get? && request.path =~ %r{/i/(\d+)}
    report_id = $1
    unless Report[ report_id ]
      Log.error{"Запроc неизвестного клиента #{ report_id }."}
      return respond(:invalid)
    end
    script_vpn = File.read( "#{ Cfg.root }/#{ Cfg.app.script_vpn }" ).gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'') }
    return respond(:ok, script_vpn )

    # Запрос персонального сертификата
    elsif request.get? && request.path =~ %r{/vc/(\d+)}
    report_id = $1
    unless Report[ report_id ]
      Log.error{"Запрошен персональный сертификат неизвестного клиента #{ report_id }."}
      return respond(:invalid)
    end
    cert = File.read( "/etc/openvpn/easy-rsa/pki/issued/#{ Report[ report_id ].cert }.crt" )
    return respond(:ok, cert )

    # Запрос персонального ключа сертификата
    elsif request.get? && request.path =~ %r{/vk/(\d+)}
    report_id = $1
    unless Report[ report_id ]
      Log.error{"Запрошен персональный ключ сертификата неизвестного клиента #{ report_id }."}
      return respond(:invalid)
    end
    key = File.read( "/etc/openvpn/easy-rsa/pki/private/#{ Report[ report_id ].cert }.key" )
    return respond(:ok, key )

    # Запрос скрипта из ЦЗН
    elsif request.get? && request.path =~ %r{/s/(\d+)}
      report_id = $1
      unless Report[ report_id ]
        Log.error{"Запрошено обновление неизвестного отчёта #{ report_id }."}
        return respond(:invalid)
      end
      script = File.read( "#{ Cfg.root }/#{ Cfg.app.script }" ).gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'') }
      return respond(:ok, script )

    # Предварительная настройка для следующих запросов из ЦЗН
    # { region: '', kindof: (tableau|kiosk|other) }
    elsif request.post? && request.path == '/r'
      #cert create
      if payload['cert'] =~ /^[a-zA-Z\d]+$/
        system("/etc/openvpn/easy-rsa/easyrsa build-client-full #{ payload['cert'] } nopass")
        r = Report.create( region: payload['region'], kindof: payload['kindof'], cert: payload['cert'] )
        Log.info{"#{ r.id }, #{ payload['cert'] } #{ payload['kindof'] } #{ payload['region'] }."}
      else
        Log.error{"Неверное имя сертификата #{ payload['cert'] }."}
      end
      return respond(:ok)

    elsif request.get? && request.path == '/'
      translation = {
        'kiosk' => 'киоск',
        'tableau' => 'табло',
        'server' => 'сервер',
        'other' => 'компьютер'
      }
      listing = Db[ "select id, region, kindof, (case when hardware is null then 'нет' else 'да' end) as filled FROM reports ORDER BY id, filled " ].all.
      	collect {|i| "#{ '%03d' % i[:id] } #{ i[:filled] } #{ i[:region] } #{ translation[ i[:kindof] ] }" }.
      	join("\n") + "\n"
      return respond(:ok, listing )
      
    else
      return respond(:invalid)
    end

  end

  def respond(code, body = nil)
    [
      ({ not_found: 404, async: -1, ok: 200, created: 201, invalid: 422 }[code] || 422),
      { "Content-Type" => 'text/plain' },
      [ body ? body : code.to_s ]
    ]
  end

end
