require 'json'
require_relative 'report'
require_relative 'monkeys'

## Вызывается из Rack::Server

class ReportServer
  # содержимое ответа той стороной не проверяется
  def call(env)
    request = Rack::Request.new( env )
    payload = case request.content_type
              when /json$/
                JSON.parse request.body.read
              when /yaml$/
                YAML.load request.body.read
              else
                t = request.body.read
                t.force_encoding( request.content_charset || 'UTF-8')
                t
              end
    Log.info{"#{ request.user_agent }:#{ request.ip } #{ request.request_method } #{ request.path }\ncontent-type: #{ request.content_type }\n#{ payload ? payload : '-' }\n===."}

    # return respond(:ok)
    return respond(:ok) if request.user_agent =~ /WhatsApp|Viber/i
    
    # Обновление данных о железе PUT /r/ID
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

    # Запрос скрипта установки vpn GET /i/ID
    elsif request.get? && request.path =~ %r{/i/(\d+)}
      report_id = $1
      unless Report[ report_id ]
        Log.error{"Запроc неизвестного клиента #{ report_id }."}
        return respond(:invalid)
      end
      script_vpn = File.read( "#{ Cfg.root }/#{ Cfg.app.script_vpn }" ).gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'') }
      return respond(:ok, script_vpn )

    # Запрос публичной части ключа GET /rsapub
    elsif request.get? && request.path =~ %r{/rsapub}
      rsa_pub = File.read( "#{ Cfg.root }/#{ Cfg.app.rsa_pub }" )
      return respond(:ok, rsa_pub )

    # Запрос персонального файла настроек для VPN GET /vpn/ID
    elsif request.get? && request.path =~ %r{/vpn/(\d+)}
      report_id = $1
      unless Report[ report_id ]
        Log.error{"Запрошены настройки VPN неизвестного клиента #{ report_id }."}
        return respond(:invalid)
      end
      cert = File.read "#{ Cfg.certs.basedir }/issued/#{ Report[ report_id ].cert }.crt"
      key  = File.read "#{ Cfg.certs.basedir }/private/#{ Report[ report_id ].cert }.key"
      base = File.read("#{ Cfg.root }/#{ Cfg.certs.client_conf }").gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'')}
      out  = <<~ECONF
        #{ base }
        <cert>
        #{ cert }
        </cert>
        <key>
        #{ key }
        </key>
      ECONF
      return respond(:ok, out )

    # Запрос скрипта диагностики из ЦЗН
    # заодно ставит VPN
    # GET /s/ID
    elsif request.get? && request.path =~ %r{/s/(\d+)}
      report_id = $1
      unless Report[ report_id ]
        Log.error{"Запрошено обновление неизвестного отчёта #{ report_id }."}
        return respond(:invalid)
      end
      script_vpn = File.read( "#{ Cfg.root }/#{ Cfg.app.script_vpn }" ).gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'') }
      script = File.read( "#{ Cfg.root }/#{ Cfg.app.script }" ).gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'') }
      return respond(:ok, script )

    # Аварийный лог установки VPN
    # PUT /r/ID/install_log
    elsif request.put? && request.path =~ %r{/r/(\d+)/install_log}
      report_id = $1
      unless r = Report[ report_id ]
        Log.error{"Запрошено обновление логов неизвестного ID #{ report_id }."}
        return respond(:invalid)
      end
      r.update install_log: payload
      Log.info{"\n#{ payload }"}
      return respond(:ok)

    # Предварительная настройка для следующих запросов из ЦЗН
    # { region: 'Название', kindof: (tableau|kiosk|other), cert: 'DN_ascii_only' }
    # POST /r
    elsif request.post? && request.path == '/r'
      #cert create
      unless payload['cert'] =~ /^[a-zA-Z0-9_-]+$/
        Log.error{"Неверное имя сертификата #{ payload['cert'] }."}
        return respond(:invalid)
      end
      unless system("#{ Cfg.certs.generator } build-client-full \"#{ payload['cert'] }\" nopass")
        Log.fatal{ "Ошибка создания сертификата для #{ payload['cert'] }." }
        return respond(:fatal)
      end
      begin
        r = Report.create( region: payload['region'], kindof: payload['kindof'], cert: payload['cert'] )
      rescue Sequel::UniqueConstraintViolation => e
        Log.error{ "Сертификат с этим именем #{ payload['cert'] } уже есть." }
        return respond(:invalid)
      end
      info = "ID:#{ r.id }, CERT:#{ payload['cert'] } #{ payload['kindof'] } #{ payload['region'] }."
      Log.info{ info }
      return respond( :ok, info )

    # Список всех записей. GET /
    elsif request.get? && request.path == '/'
      translation = {
        'kiosk' => 'киоск',
        'tableau' => 'табло',
        'server' => 'сервер',
        'other' => 'компьютер'
      }
      listing = Db[ <<~ELISTING ].all.
        SELECT id, region, kindof,
          ( CASE WHEN cert IS NULL then '-vpn' ELSE cert END ) AS vpn,
          ( CASE WHEN hardware IS NULL THEN 'нет' ELSE 'да' END) AS filled FROM reports ORDER BY id, filled, vpn
        ELISTING
      	collect {|i| "#{ '%03d' % i[:id] } #{ i[:filled] } #{ i[:region] } #{ translation[ i[:kindof] ] } #{ i[:vpn] }" }.
      	join("\n") + "\n"
      return respond(:ok, listing )
      
    else
      return respond(:invalid)
    end

  end

  def respond(code, body = nil)
    [
      ({ not_found: 404, async: -1, ok: 200, created: 201, invalid: 422, fatal: 500 }[code] || 422),
      { "Content-Type" => 'text/plain' },
      [ body ? body : code.to_s ]
    ]
  end

end
