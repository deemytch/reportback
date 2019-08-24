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
      r = Report.create( region: payload['region'], kindof: payload['kindof'] )
      Log.info{"#{ r.id }, #{ payload['kindof'] } #{ payload['region'] }."}
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
